import AppKit
import PDFKit
import UniformTypeIdentifiers

struct ExportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class Droplet: NSObject, NSApplicationDelegate {
    private let files = FileManager.default
    private var pending: [URL] = []
    private var processing = false
    private var helpTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard pending.isEmpty, !processing else { return }
        helpTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.chooseDocuments()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        helpTimer?.invalidate()
        helpTimer = nil
        pending.append(contentsOf: urls)
        guard !processing else { return }
        processing = true
        DispatchQueue.main.async { self.processDocuments() }
    }

    private func activate() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func chooseDocuments() {
        activate()
        let panel = NSOpenPanel()
        panel.message = "Choisissez les documents Pages à convertir en PDF."
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType(filenameExtension: "pages") ?? .item]
        } else {
            panel.allowedFileTypes = ["pages"]
        }
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            application(NSApp, open: panel.urls)
        } else if !processing {
            NSApp.terminate(nil)
        }
    }

    private func processDocuments() {
        var failures: [String] = []
        do {
            let pages = try findPages()
            guard let scriptURL = Bundle.main.url(forResource: "Export", withExtension: "applescript"),
                  let source = try? String(contentsOf: scriptURL, encoding: .utf8),
                  let script = NSAppleScript(source: source) else {
                throw ExportError(message: "Le script d’export est introuvable. Réinstallez Pagetopdf.")
            }
            while !pending.isEmpty {
                let batch = pending
                pending.removeAll()
                for source in batch {
                    do {
                        try export(source, script: script, pages: pages)
                    } catch {
                        failures.append("\(source.lastPathComponent) — \(error.localizedDescription)")
                        if (error as NSError).code == -1743 {
                            pending.removeAll()
                            throw ExportError(message: "Autorisez Pagetopdf à contrôler Pages dans Réglages ou Préférences Système → Confidentialité → Automatisation, puis déposez de nouveau les fichiers qui restent à convertir.")
                        }
                    }
                }
            }
        } catch {
            failures.append(error.localizedDescription)
        }

        if !failures.isEmpty {
            activate()
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Conversion incomplète"
            alert.informativeText = failures.joined(separator: "\n\n")
            alert.runModal()
        }

        processing = false
        if pending.isEmpty {
            NSApp.terminate(nil)
        } else {
            processing = true
            DispatchQueue.main.async { self.processDocuments() }
        }
    }

    private func findPages() throws -> URL {
        let identifiers = ["com.apple.iWork.Pages", "com.apple.Pages"]
        for identifier in identifiers {
            if let url = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first?.bundleURL {
                return url
            }
        }
        for identifier in identifiers {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
                  let bundle = Bundle(url: url), bundle.executableURL != nil else { continue }
            if let minimum = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String {
                let parts = minimum.split(separator: ".").compactMap { Int($0) }
                if let major = parts.first {
                    let required = OperatingSystemVersion(majorVersion: major,
                        minorVersion: parts.dropFirst().first ?? 0,
                        patchVersion: parts.dropFirst(2).first ?? 0)
                    guard ProcessInfo.processInfo.isOperatingSystemAtLeast(required) else { continue }
                }
            }
            return url
        }
        throw ExportError(message: "Installez une version d’Apple Pages compatible avec votre Mac.")
    }

    private func export(_ source: URL, script: NSAppleScript, pages: URL) throws {
        guard source.isFileURL, source.pathExtension.lowercased() == "pages",
              files.fileExists(atPath: source.path) else {
            throw ExportError(message: "Sélectionnez un document .pages accessible.")
        }
        let folder = source.deletingLastPathComponent()
        let stem = source.deletingPathExtension().lastPathComponent
        let staging = folder.appendingPathComponent(".Pagetopdf-\(UUID().uuidString)", isDirectory: true)
        try files.createDirectory(at: staging, withIntermediateDirectories: false,
                                  attributes: [.posixPermissions: 0o700])
        defer { try? files.removeItem(at: staging) }
        let temporaryPDF = staging.appendingPathComponent("Export.pdf")

        // Pass data as Apple event descriptors so paths are never interpreted as script text.
        let args = NSAppleEventDescriptor.list()
        for (index, value) in [pages.path, source.path, temporaryPDF.path].enumerated() {
            args.insert(NSAppleEventDescriptor(string: value), at: index + 1)
        }
        let event = NSAppleEventDescriptor(eventClass: 0x61736372, eventID: 0x70736272,
                                           targetDescriptor: .currentProcess(),
                                           returnID: -1, transactionID: 0)
        event.setParam(NSAppleEventDescriptor(string: "exportpdf"), forKeyword: 0x736e616d)
        event.setParam(args, forKeyword: 0x2d2d2d2d)
        var details: NSDictionary?
        script.executeAppleEvent(event, error: &details)
        if let details {
            throw NSError(domain: "AppleScript",
                          code: details[NSAppleScript.errorNumber] as? Int ?? 0,
                          userInfo: [NSLocalizedDescriptionKey:
                            details[NSAppleScript.errorMessage] as? String ?? "Échec de l’export dans Pages."])
        }
        guard let pdf = PDFDocument(url: temporaryPDF), pdf.pageCount > 0 else {
            throw ExportError(message: "Pages n’a pas produit de PDF lisible.")
        }

        var number = 1
        while true {
            let name = number == 1 ? stem : "\(stem) (\(number))"
            let destination = folder.appendingPathComponent(name).appendingPathExtension("pdf")
            do {
                try files.moveItem(at: temporaryPDF, to: destination)
                return
            } catch let error as NSError where error.domain == NSCocoaErrorDomain &&
                error.code == NSFileWriteFileExistsError {
                number += 1
            }
        }
    }
}

let app = NSApplication.shared
let delegate = Droplet()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

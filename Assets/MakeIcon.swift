import CoreGraphics
import Foundation
import ImageIO

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let rgb = CGColorSpaceCreateDeviceRGB()

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func drawIcon(size: Int) throws -> CGImage {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: rgb,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)

    func rounded(_ rect: CGRect, radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    func fill(_ path: CGPath, _ hex: UInt32) {
        context.setFillColor(color(hex))
        context.addPath(path)
        context.fillPath()
    }

    func gradient(_ path: CGPath, from top: UInt32, to bottom: UInt32, y: ClosedRange<CGFloat>) {
        context.saveGState()
        context.addPath(path)
        context.clip()
        let colors = [color(top), color(bottom)] as CFArray
        let shading = CGGradient(colorsSpace: rgb, colors: colors, locations: [0, 1])!
        context.drawLinearGradient(shading, start: CGPoint(x: 512, y: y.lowerBound),
                                   end: CGPoint(x: 512, y: y.upperBound), options: [])
        context.restoreGState()
    }

    let tile = rounded(CGRect(x: 56, y: 56, width: 912, height: 912), radius: 205)
    gradient(tile, from: 0xEB6545, to: 0xAA261E, y: 56...968)

    let sheet = CGMutablePath()
    sheet.move(to: CGPoint(x: 342, y: 210))
    sheet.addLine(to: CGPoint(x: 570, y: 210))
    sheet.addLine(to: CGPoint(x: 735, y: 375))
    sheet.addLine(to: CGPoint(x: 735, y: 747))
    sheet.addQuadCurve(to: CGPoint(x: 681, y: 801), control: CGPoint(x: 735, y: 801))
    sheet.addLine(to: CGPoint(x: 342, y: 801))
    sheet.addQuadCurve(to: CGPoint(x: 288, y: 747), control: CGPoint(x: 288, y: 801))
    sheet.addLine(to: CGPoint(x: 288, y: 264))
    sheet.addQuadCurve(to: CGPoint(x: 342, y: 210), control: CGPoint(x: 288, y: 210))
    sheet.closeSubpath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -16 * scale), blur: 30 * scale,
                      color: color(0x772015).copy(alpha: 0.5))
    fill(sheet, 0xFFFFFF)
    context.restoreGState()
    gradient(sheet, from: 0xFFFFFF, to: 0xFFE8DF, y: 210...801)

    let fold = CGMutablePath()
    fold.move(to: CGPoint(x: 570, y: 210))
    fold.addLine(to: CGPoint(x: 735, y: 375))
    fold.addLine(to: CGPoint(x: 610, y: 375))
    fold.addQuadCurve(to: CGPoint(x: 570, y: 335), control: CGPoint(x: 570, y: 375))
    fold.closeSubpath()
    fill(fold, 0xF6C3B6)

    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 512, y: 397))
    arrow.addLine(to: CGPoint(x: 512, y: 606))
    arrow.move(to: CGPoint(x: 414, y: 518))
    arrow.addLine(to: CGPoint(x: 512, y: 616))
    arrow.addLine(to: CGPoint(x: 610, y: 518))
    context.addPath(arrow)
    context.setStrokeColor(color(0xA62D22))
    context.setLineWidth(53)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
    fill(rounded(CGRect(x: 391, y: 685, width: 242, height: 48), radius: 24), 0xA62D22)
    return context.makeImage()!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let url = output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, try drawIcon(size: points * scale), nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

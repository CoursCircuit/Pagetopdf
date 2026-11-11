#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  ""|--build-only|--verify) ;;
  *) echo "Usage: $0 [--build-only|--verify]" >&2; exit 2 ;;
esac

mkdir -p .build dist
sdk="$(xcrun --sdk macosx --show-sdk-path)"
staging=$(mktemp -d "$PWD/.build/stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
app="$staging/Pagetopdf.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Sources/Info.plist "$app/Contents/"
cp Sources/Export.applescript Assets/Pagetopdf.icns "$app/Contents/Resources/"
osacompile -o "$staging/Export.scpt" Sources/Export.applescript
for arch in arm64 x86_64; do
  version=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersionByArchitecture:$arch" Sources/Info.plist)
  xcrun swiftc -O -module-cache-path "$PWD/.build/ModuleCache" -sdk "$sdk" -target "$arch-apple-macos$version" \
    Sources/main.swift -o "$staging/Pagetopdf-$arch"
done
xcrun lipo -create "$staging/Pagetopdf-arm64" "$staging/Pagetopdf-x86_64" \
  -output "$app/Contents/MacOS/Pagetopdf"

xattr -cr "$app"
identity="${PAGETOPDF_SIGN_IDENTITY:--}"
if [[ "$identity" == "Developer ID Application:"* ]]; then
  codesign --sign "$identity" --options runtime --timestamp \
    --entitlements Sources/Entitlements.plist "$app"
else
  codesign --sign "$identity" --entitlements Sources/Entitlements.plist "$app"
fi
codesign --verify --strict "$app"
rm -rf dist/Pagetopdf.app
mv "$app" dist/
if [[ "${1:-}" != --build-only ]]; then
  open "$PWD/dist/Pagetopdf.app"
  if [[ "${1:-}" == --verify ]]; then
    sleep 1
    pgrep -fx "$PWD/dist/Pagetopdf.app/Contents/MacOS/Pagetopdf"
  fi
fi

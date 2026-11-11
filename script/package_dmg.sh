#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

app=dist/Pagetopdf.app
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
dmg="$PWD/dist/Pagetopdf-$version-universal.dmg"
stage=$(mktemp -d "${TMPDIR:-/tmp}/pagetopdf-dmg.XXXXXX")
mountpoint="$stage/mounted"
mounted=false
cleanup() {
  if $mounted; then
    hdiutil detach "$mountpoint" >/dev/null || return
  fi
  rm -rf "$stage"
}
trap cleanup EXIT

mkdir "$stage/payload" "$mountpoint"
ditto --norsrc --noextattr "$app" "$stage/payload/Pagetopdf.app"
xattr -cr "$stage/payload/Pagetopdf.app"
codesign --verify --strict "$stage/payload/Pagetopdf.app"
ln -s /Applications "$stage/payload/Applications"
hdiutil create -ov -volname Pagetopdf -fs 'HFS+' -srcfolder "$stage/payload" -format UDZO "$stage/Pagetopdf.dmg"
hdiutil verify "$stage/Pagetopdf.dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$mountpoint" "$stage/Pagetopdf.dmg"
mounted=true
codesign --verify --strict "$mountpoint/Pagetopdf.app"
cmp "$mountpoint/Pagetopdf.app/Contents/MacOS/Pagetopdf" "$app/Contents/MacOS/Pagetopdf"
test "$(readlink "$mountpoint/Applications")" = /Applications
hdiutil detach "$mountpoint"
mounted=false
mv -f "$stage/Pagetopdf.dmg" "$dmg"
shasum -a 256 "$dmg"

#!/bin/sh
# Builds dist/XattotInputMethod.app: a universal input method with the word lists inside. Installs nothing.
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
IM="$ROOT/inputmethod"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
APP="$ROOT/dist/XattotInputMethod.app"
BIN="$APP/Contents/MacOS/XattotInputMethod"

for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos13" -module-name XattotInputMethod \
    -o "$WORK/XattotInputMethod-$ARCH" \
    "$IM"/Sources/Engine/*.swift "$IM"/Sources/Host/*.swift "$IM"/App/*.swift
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$WORK/XattotInputMethod-arm64" "$WORK/XattotInputMethod-x86_64" -output "$BIN"
cp "$IM"/Resources/* "$APP/Contents/Resources/"
cp "$ROOT/assets/Layout.icns" "$APP/Contents/Resources/Layout.icns"
cp "$IM/App/Info.plist" "$APP/Contents/Info.plist"

# CFBundleVersion identifies the exact binary and resources, so two builds differ only if their contents do.
VERSION=$(cd "$APP/Contents" && find MacOS Resources -type f | LC_ALL=C sort \
  | while IFS= read -r f; do cat "$f"; done | shasum -a 256 | cut -c1-12)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

# Ad-hoc signature with the hardened runtime: an input method loads this way without a Developer ID.
codesign --force --options runtime --sign - "$APP"
echo "$APP"

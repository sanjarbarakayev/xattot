#!/bin/sh
# Builds dist/Xattot.app: a universal menu bar app with the layout bundle and input method inside.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
APP="$ROOT/dist/Xattot.app"

python3 "$ROOT/build.py" >/dev/null
"$ROOT/inputmethod/scripts/build.sh" >/dev/null

for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos13" \
    -o "$WORK/Xattot-$ARCH" "$ROOT"/app/Sources/*.swift
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$WORK/Xattot-arm64" "$WORK/Xattot-x86_64" -output "$APP/Contents/MacOS/Xattot"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/dist/Xattot.bundle" "$APP/Contents/Resources/"
cp -R "$ROOT/dist/XattotInputMethod.app" "$APP/Contents/Resources/"

# Ad-hoc signature: required to run on Apple silicon; not a Developer ID.
# Hardened runtime already on, as notarization will require it.
codesign --force --options runtime --sign - "$APP"
echo "$APP"

#!/bin/sh
# Throwaway spike: builds XattotSpike.app and installs it into ~/Library/Input Methods.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
APP="$HERE/build/XattotSpike.app"
DEST="$HOME/Library/Input Methods/XattotSpike.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target arm64-apple-macos13 -module-name XattotSpike \
  -o "$APP/Contents/MacOS/XattotSpike" "$HERE/main.swift" "$HERE/Controller.swift"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
codesign --force --options runtime --sign - "$APP"

pkill -x XattotSpike 2>/dev/null || true
mkdir -p "$HOME/Library/Input Methods"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

# Sandboxed apps cache their own input source table; one built before this source
# crashes on switching to it (CFRelease(NULL) in TextInputUIMacHelper). Same fix as
# the free app's LayoutInstaller: drop the caches, macOS rebuilds them.
CACHE=$(getconf DARWIN_USER_CACHE_DIR)
find "$CACHE" -maxdepth 2 -name 'com.apple.IntlDataCache.le*' -delete 2>/dev/null || true
echo "$DEST"

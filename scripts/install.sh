#!/bin/sh
# Installs the layout for the current user. Add it afterwards in
# System Settings > Keyboard > Input Sources > Edit > + > Uzbek.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$HOME/Library/Keyboard Layouts"

python3 "$ROOT/build.py" >/dev/null
mkdir -p "$DEST"
rm -rf "$DEST/Xattot.bundle"
cp -R "$ROOT/dist/Xattot.bundle" "$DEST/"
# Stale input source tables, shared and per sandboxed app: without this macOS serves the old layout,
# and sandboxed apps that predate the install crash when Fn switches to it.
CACHE=$(getconf DARWIN_USER_CACHE_DIR)
rm -f "$CACHE"com.apple.IntlDataCache.le* "$CACHE"*/com.apple.IntlDataCache.le*
# A cache rebuilt mid-copy can miss one of the two layouts; registering the bundle adds both.
swift "$ROOT/scripts/register_layout.swift" "$DEST/Xattot.bundle"
echo "Installed to $DEST/Xattot.bundle"
echo "Log out and back in if the Özbekça layouts, Özbekça (Xattot) and Özbekça Tugmali (Xattot), are not listed under Input Sources yet."

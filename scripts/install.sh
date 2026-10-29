#!/bin/sh
# Installs the layout and the input method for the current user. Add it afterwards in
# System Settings > Keyboard > Input Sources > Edit > + > Uzbek.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$HOME/Library/Keyboard Layouts"

python3 "$ROOT/build.py" >/dev/null
"$ROOT/inputmethod/scripts/build.sh" >/dev/null
mkdir -p "$DEST"
rm -rf "$DEST/Xattot.bundle"
cp -R "$ROOT/dist/Xattot.bundle" "$DEST/"
# Stale input source tables, shared and per sandboxed app: without this macOS serves the old layout,
# and sandboxed apps that predate the install crash when Fn switches to it.
CACHE=$(getconf DARWIN_USER_CACHE_DIR)
rm -f "$CACHE"com.apple.IntlDataCache.le* "$CACHE"*/com.apple.IntlDataCache.le*
# A cache rebuilt mid-copy can miss one of the two layouts; registering the bundle adds both.
swift "$ROOT/scripts/register_layout.swift" "$DEST/Xattot.bundle"
IM_DEST="$HOME/Library/Input Methods"
# A running copy keeps the old code, so stop it before replacing.
pkill -x XattotInputMethod 2>/dev/null || true
mkdir -p "$IM_DEST"
rm -rf "$IM_DEST/XattotInputMethod.app"
cp -R "$ROOT/dist/XattotInputMethod.app" "$IM_DEST/"
echo "Installed to $DEST/Xattot.bundle"
echo "Installed to $IM_DEST/XattotInputMethod.app"
echo "Log out and back in if the Özbekça layouts, Özbekça Klassik (Xattot) and Özbekça Tugmali (Xattot), are not listed under Input Sources yet."

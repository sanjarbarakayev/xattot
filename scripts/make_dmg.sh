#!/bin/sh
# Packs the menu bar app into a drag-to-Applications DMG for sharing, plus the bare
# layout as a zip for people who want it without the app.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
OUT="$ROOT/dist/Xattot.dmg"
VENV="$ROOT/.venv"

"$ROOT/scripts/build_app.sh" >/dev/null

[ -x "$VENV/bin/pip" ] || python3 -m venv "$VENV"
# Runs every time so an existing venv follows the pinned versions; pip skips what is already installed.
"$VENV/bin/pip" install -q --disable-pip-version-check --require-hashes -r "$ROOT/scripts/dmg/requirements.txt"

swiftc -swift-version 5 -o "$WORK/background" "$ROOT/scripts/dmg/background.swift"
"$WORK/background" "$WORK/bg.png" 1
"$WORK/background" "$WORK/bg@2x.png" 2
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/background.tiff" 2>/dev/null

cp "$ROOT/assets/Ornatish.txt" "$WORK/Örnatiş.txt"

rm -f "$OUT"
# ASCII volume name: the background is found through an alias that records it.
"$VENV/bin/dmgbuild" -s "$ROOT/scripts/dmg/settings.py" \
  -D app="$ROOT/dist/Xattot.app" \
  -D notes="$WORK/Örnatiş.txt" \
  -D background="$WORK/background.tiff" \
  "Xattot" "$OUT" >/dev/null

(cd "$ROOT/dist" && rm -f Xattot-layout.zip && ditto -c -k --keepParent Xattot.bundle Xattot-layout.zip)
echo "$OUT"

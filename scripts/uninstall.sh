#!/bin/sh
# Removes the input method and the layout, the layout from both per-user and system-wide folders.
set -eu

pkill -x XattotInputMethod 2>/dev/null || true
rm -rf "$HOME/Library/Input Methods/XattotInputMethod.app"
defaults delete com.sanjarbarakayev.inputmethod.xattot 2>/dev/null || true
rm -rf "$HOME/Library/Keyboard Layouts/Xattot.bundle"
if [ -e "/Library/Keyboard Layouts/Xattot.bundle" ]; then
  sudo rm -rf "/Library/Keyboard Layouts/Xattot.bundle"
fi
echo "Removed. Remove Özbekça (Xattot), Özbekça Klassik (Xattot) and Özbekça Tugmali (Xattot) from Input Sources if they are still listed."

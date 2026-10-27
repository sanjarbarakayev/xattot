#!/bin/sh
# Removes the layout from both per-user and system-wide Keyboard Layouts folders.
set -eu

rm -rf "$HOME/Library/Keyboard Layouts/Xattot.bundle"
if [ -e "/Library/Keyboard Layouts/Xattot.bundle" ]; then
  sudo rm -rf "/Library/Keyboard Layouts/Xattot.bundle"
fi
echo "Removed. Remove Özbek (Lotin) from Input Sources if it is still listed."

#!/bin/sh
# Fails if any executable in the app, nested apps included, links a networking library or imports
# any networking symbol. Anyone can run it against a downloaded copy:
#   scripts/check_no_network.sh "/Applications/Xattot.app"
set -eu

APP=${1:-"$(cd "$(dirname "$0")/.." && pwd)/dist/Xattot.app"}
PATTERN='socket|connect|getaddrinfo|gethostbyname|sendto|recvfrom|URLSession|NSURLConnection|URLRequest|CFNetwork|CFSocket|CFHTTP|CFStreamCreatePairWith|nw_|Network\.framework|WebKit'

if [ ! -d "$APP" ]; then
  echo "no app at $APP"
  exit 1
fi

status=0
checked=0
# Contents/MacOS of the app and of every bundle nested inside it; lipo skips what is not Mach-O.
BINS=$(find "$APP" -path '*/Contents/MacOS/*' -type f)
IFS='
'
for BIN in $BINS; do
  ARCHS=$(lipo -archs "$BIN" 2>/dev/null) || continue
  checked=$((checked + 1))
  NAME=${BIN#"$APP"/}
  for ARCH in $(printf '%s\n' "$ARCHS" | tr ' ' '\n'); do
    libs=$(otool -arch "$ARCH" -L "$BIN" | tail -n +2)
    symbols=$(nm -arch "$ARCH" -u "$BIN")
    hits=$(printf '%s\n%s\n' "$libs" "$symbols" | grep -E "$PATTERN" || true)
    if [ -n "$hits" ]; then
      echo "[$NAME $ARCH] networking references found:"
      echo "$hits"
      status=1
    else
      echo "[$NAME $ARCH] no networking libraries or symbols ($(printf '%s\n' "$symbols" | wc -l | tr -d ' ') imported symbols checked)"
    fi
  done
done

if [ "$checked" -eq 0 ]; then
  echo "no executables in $APP"
  exit 1
fi
exit $status

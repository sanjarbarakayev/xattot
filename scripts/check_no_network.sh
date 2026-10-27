#!/bin/sh
# Fails if the app binary links a networking library or imports any networking symbol.
# Anyone can run it against a downloaded copy: scripts/check_no_network.sh "/Applications/Xattot.app"
set -eu

APP=${1:-"$(cd "$(dirname "$0")/.." && pwd)/dist/Xattot.app"}
BIN="$APP/Contents/MacOS/Xattot"
PATTERN='socket|connect|getaddrinfo|gethostbyname|sendto|recvfrom|URLSession|NSURLConnection|URLRequest|CFNetwork|CFSocket|CFHTTP|CFStreamCreatePairWith|nw_|Network\.framework|WebKit'

status=0
for ARCH in $(lipo -archs "$BIN"); do
  libs=$(otool -arch "$ARCH" -L "$BIN" | tail -n +2)
  symbols=$(nm -arch "$ARCH" -u "$BIN")
  hits=$(printf '%s\n%s\n' "$libs" "$symbols" | grep -E "$PATTERN" || true)
  if [ -n "$hits" ]; then
    echo "[$ARCH] networking references found:"
    echo "$hits"
    status=1
  else
    echo "[$ARCH] no networking libraries or symbols ($(printf '%s\n' "$symbols" | wc -l | tr -d ' ') imported symbols checked)"
  fi
done
exit $status

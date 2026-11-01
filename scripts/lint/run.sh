#!/bin/sh
# Checks formatting and lint for Python (ruff), C++ (clang-format) and Swift (swift-format).
# With --fix it rewrites the files instead. Python tools come pinned from requirements.txt;
# swift-format is the toolchain's, and CI's Xcode version is the one that decides.
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VENV="$ROOT/.venv"
cd "$ROOT"

[ -x "$VENV/bin/pip" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --disable-pip-version-check --require-hashes -r scripts/lint/requirements.txt

CPP=$(git ls-files '*.cpp' '*.h')
SWIFT=$(git ls-files '*.swift')

if [ "${1:-}" = "--fix" ]; then
  # Findings with no automatic fix are left for `make lint` to report.
  "$VENV/bin/ruff" check --fix --exit-zero .
  "$VENV/bin/ruff" format .
  "$VENV/bin/clang-format" -i $CPP
  swift format format --in-place --parallel $SWIFT
  exit 0
fi

status=0
"$VENV/bin/ruff" check . || status=1
"$VENV/bin/ruff" format --check . || status=1
"$VENV/bin/clang-format" --dry-run -Werror $CPP || status=1
swift format lint --strict --parallel $SWIFT || status=1
[ $status -eq 0 ] || echo "lint: run 'make format' to fix formatting; other findings need a manual fix" >&2
exit $status

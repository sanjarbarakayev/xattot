#!/usr/bin/env python3
"""Sets the version and SHA-256 of the Homebrew cask to a new release.

Usage: update_cask.py <cask.rb> <version> <sha256>
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

VERSION = re.compile(r'^(  version ")[^"]*(")$', re.MULTILINE)
SHA256 = re.compile(r'^(  sha256 ")[^"]*(")$', re.MULTILINE)


def update(cask: str, version: str, sha256: str) -> str:
    # Both values land inside a Ruby string, so anything but the expected shape is refused.
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError(f"not a release version: {version!r}")
    if not re.fullmatch(r"[0-9a-f]{64}", sha256):
        raise ValueError(f"not a SHA-256 in lowercase hex: {sha256!r}")
    for name, pattern in (("version", VERSION), ("sha256", SHA256)):
        if len(pattern.findall(cask)) != 1:
            raise ValueError(f"the cask needs exactly one top-level {name} stanza")
    cask = VERSION.sub(rf"\g<1>{version}\g<2>", cask)
    return SHA256.sub(rf"\g<1>{sha256}\g<2>", cask)


def main() -> None:
    path, version, sha256 = sys.argv[1:]
    cask = Path(path)
    cask.write_text(update(cask.read_text(encoding="utf-8"), version, sha256), encoding="utf-8")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Packs PNG files into a Windows .ico (PNG entries, Windows Vista and later).
Usage: make_ico.py <out.ico> <png>..., each PNG square."""

from __future__ import annotations

import struct
import sys
from pathlib import Path


def png_side(data: bytes) -> int:
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    if width != height:
        raise ValueError(f"not square: {width}x{height}")
    return width


def main() -> None:
    out, sources = Path(sys.argv[1]), [Path(p) for p in sys.argv[2:]]
    images = sorted(((png_side(data), data) for data in (p.read_bytes() for p in sources)), key=lambda i: i[0])
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)
    entries, payload = b"", b""
    for side, data in images:
        # A side of 256 is written as 0.
        entries += struct.pack("<BBBBHHII", side % 256, side % 256, 0, 0, 1, 32, len(data), offset + len(payload))
        payload += data
    out.write_bytes(header + entries + payload)


if __name__ == "__main__":
    main()

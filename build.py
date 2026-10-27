#!/usr/bin/env python3
"""Builds dist/Xattot.bundle from the rules in uzkbd/."""

from __future__ import annotations

from pathlib import Path

from uzkbd.bundle import write_bundle
from uzkbd.layout import build_layout
from uzkbd.xml_writer import to_xml

ROOT = Path(__file__).resolve().parent


def main() -> None:
    icon = ROOT / "assets" / "Layout.icns"
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    bundle = write_bundle(dist, to_xml(build_layout()), icon if icon.exists() else None)
    print(bundle)


if __name__ == "__main__":
    main()

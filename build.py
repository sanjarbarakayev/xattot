#!/usr/bin/env python3
"""Builds dist/Xattot.bundle from the rules in uzkbd/."""

from __future__ import annotations

from pathlib import Path

from uzkbd import tugmali
from uzkbd.bundle import BundledLayout, write_bundle
from uzkbd.layout import NAME, build_layout
from uzkbd.xml_writer import to_xml

ROOT = Path(__file__).resolve().parent


def main() -> None:
    icon = ROOT / "assets" / "Layout.icns"
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    layouts = [
        BundledLayout(NAME, "Özbekça Klassik (Xattot)", to_xml(build_layout())),
        BundledLayout(tugmali.NAME, "Özbekça Tugmali (Xattot)", to_xml(tugmali.build_tugmali())),
    ]
    bundle = write_bundle(dist, layouts, icon if icon.exists() else None)
    print(bundle)


if __name__ == "__main__":
    main()

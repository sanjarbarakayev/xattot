"""Builds dist/Xattot.bundle from the rules in uzkbd/.

Run from the repo root: python3 -m uzkbd.build
"""

from __future__ import annotations

from pathlib import Path

from uzkbd import tugmali
from uzkbd.bundle import BundledLayout, write_bundle
from uzkbd.xml_writer import to_xml

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    icon = ROOT / "assets" / "Layout.icns"
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    layouts = [BundledLayout(tugmali.NAME, "Özbekça Tugmali (Xattot)", to_xml(tugmali.build_tugmali()))]
    bundle = write_bundle(dist, layouts, icon if icon.exists() else None)
    print(bundle)


if __name__ == "__main__":
    main()

"""Writes the .bundle macOS loads from a Keyboard Layouts folder."""

from __future__ import annotations

import hashlib
import plistlib
import shutil
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

BUNDLE_ID = "com.sanjarbarakayev.keyboardlayout.xattot"
BUNDLE_NAME = "Xattot"
VERSION = "1.0.0"


@dataclass(frozen=True)
class BundledLayout:
    name: str
    display_name: str
    xml: str


def source_id(name: str) -> str:
    # macOS derives this from the bundle id and layout name; Info.plist must match it.
    return f"{BUNDLE_ID}.keylayout.{name.replace(' ', '')}"


def write_bundle(dest: Path, layouts: Sequence[BundledLayout], icon: Path | None) -> Path:
    bundle = dest / f"{BUNDLE_NAME}.bundle"
    if bundle.exists():
        shutil.rmtree(bundle)
    resources = bundle / "Contents" / "Resources"
    (resources / "en.lproj").mkdir(parents=True)

    infos = {layout.name: _layout_info(layout.name) for layout in layouts}
    for layout in layouts:
        (resources / f"{layout.name}.keylayout").write_text(layout.xml, encoding="utf-8")
        if icon is not None:
            shutil.copyfile(icon, resources / f"{layout.name}.icns")
    (resources / "en.lproj" / "InfoPlist.strings").write_text(
        "".join(f'"{layout.name}" = "{layout.display_name}";\n' for layout in layouts),
        encoding="utf-8",
    )
    with (bundle / "Contents" / "Info.plist").open("wb") as f:
        plistlib.dump(
            {
                "CFBundleIdentifier": BUNDLE_ID,
                "CFBundleName": BUNDLE_NAME,
                "CFBundleDevelopmentRegion": "en",
                # Content hash, so the menu bar app replaces an installed copy whenever the bundle changes.
                "CFBundleVersion": _content_hash(layouts, icon, infos),
                "CFBundleShortVersionString": VERSION,
                **{f"KLInfo_{name}": info for name, info in infos.items()},
            },
            f,
        )
    return bundle


def _layout_info(name: str) -> dict:
    return {
        "TISInputSourceID": source_id(name),
        "TISIntendedLanguage": "uz-Latn",
        # macOS ignores TISIconLabels for layout bundles, so the icns itself is drawn as an outlined badge.
        "TISIconIsTemplate": True,
    }


def _content_hash(layouts: Sequence[BundledLayout], icon: Path | None, infos: dict) -> str:
    digest = hashlib.sha256()
    for layout in layouts:
        digest.update(layout.xml.encode("utf-8"))
        digest.update(plistlib.dumps(infos[layout.name], sort_keys=True))
        digest.update(layout.display_name.encode("utf-8"))
    if icon is not None:
        digest.update(icon.read_bytes())
    return digest.hexdigest()[:12]

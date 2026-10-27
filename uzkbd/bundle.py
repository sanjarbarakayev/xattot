"""Writes the .bundle macOS loads from a Keyboard Layouts folder."""

from __future__ import annotations

import hashlib
import plistlib
import shutil
from pathlib import Path
from typing import Optional

from .layout import NAME

BUNDLE_ID = "com.sanjarbarakayev.keyboardlayout.xattot"
# macOS derives this from the bundle id and layout name; Info.plist must match it.
SOURCE_ID = f"{BUNDLE_ID}.keylayout.{NAME.replace(' ', '')}"
DISPLAY_NAME = "Özbek (Lotin)"
VERSION = "1.0.0"


def write_bundle(dest: Path, xml: str, icon: Optional[Path]) -> Path:
    bundle = dest / "Xattot.bundle"
    if bundle.exists():
        shutil.rmtree(bundle)
    resources = bundle / "Contents" / "Resources"
    (resources / "en.lproj").mkdir(parents=True)

    (resources / f"{NAME}.keylayout").write_text(xml, encoding="utf-8")
    if icon is not None:
        shutil.copyfile(icon, resources / f"{NAME}.icns")
    (resources / "en.lproj" / "InfoPlist.strings").write_text(
        f'"{NAME}" = "{DISPLAY_NAME}";\n', encoding="utf-8"
    )
    layout_info = {
        "TISInputSourceID": SOURCE_ID,
        "TISIntendedLanguage": "uz-Latn",
        # macOS ignores TISIconLabels for layout bundles, so the icns itself is drawn as an outlined badge.
        "TISIconIsTemplate": True,
    }
    with (bundle / "Contents" / "Info.plist").open("wb") as f:
        plistlib.dump(
            {
                "CFBundleIdentifier": BUNDLE_ID,
                "CFBundleName": DISPLAY_NAME,
                "CFBundleDevelopmentRegion": "en",
                # Content hash, so the menu bar app replaces an installed copy whenever the bundle changes.
                "CFBundleVersion": _content_hash(xml, icon, layout_info),
                "CFBundleShortVersionString": VERSION,
                f"KLInfo_{NAME}": layout_info,
            },
            f,
        )
    return bundle


def _content_hash(xml: str, icon: Optional[Path], layout_info: dict) -> str:
    digest = hashlib.sha256(xml.encode("utf-8"))
    digest.update(plistlib.dumps(layout_info, sort_keys=True))
    if icon is not None:
        digest.update(icon.read_bytes())
    return digest.hexdigest()[:12]

"""The bundle carries every layout it is given, and the digraph layout keeps its identity."""

from __future__ import annotations

import plistlib
import tempfile
import unittest
from pathlib import Path

from uzkbd.bundle import BundledLayout, source_id, write_bundle
from uzkbd.layout import build_layout
from uzkbd.xml_writer import to_xml

ICON_BYTES = b"icns-test"


def _write(layouts: list[BundledLayout]) -> Path:
    tmp = Path(tempfile.mkdtemp())
    icon = tmp / "Layout.icns"
    icon.write_bytes(ICON_BYTES)
    return write_bundle(tmp, layouts, icon)


def _info(bundle: Path) -> dict:
    with (bundle / "Contents" / "Info.plist").open("rb") as f:
        return plistlib.load(f)


class BundleTest(unittest.TestCase):
    def test_digraph_identity_is_unchanged(self) -> None:
        layout = build_layout()
        expected = "com.sanjarbarakayev.keyboardlayout.xattot.keylayout.UzbekLatin"
        self.assertEqual(layout.name, "Uzbek Latin")
        self.assertEqual(layout.layout_id, -20260)
        self.assertEqual(source_id("Uzbek Latin"), expected)

        bundle = _write([BundledLayout("Uzbek Latin", "Özbekça Klassik (Xattot)", to_xml(layout))])
        self.assertEqual(_info(bundle)["KLInfo_Uzbek Latin"]["TISInputSourceID"], expected)

    def test_each_layout_gets_files_and_info(self) -> None:
        bundle = _write(
            [
                BundledLayout("Uzbek Latin", "Özbekça Klassik (Xattot)", "<a/>"),
                BundledLayout("Test Two", "Test Two Display", "<b/>"),
            ]
        )
        resources = bundle / "Contents" / "Resources"
        info = _info(bundle)
        self.assertEqual(info["CFBundleName"], "Xattot")
        for name in ("Uzbek Latin", "Test Two"):
            self.assertTrue((resources / f"{name}.keylayout").exists())
            self.assertEqual((resources / f"{name}.icns").read_bytes(), ICON_BYTES)
            self.assertEqual(info[f"KLInfo_{name}"]["TISInputSourceID"], source_id(name))
        strings = (resources / "en.lproj" / "InfoPlist.strings").read_text(encoding="utf-8")
        self.assertIn('"Uzbek Latin" = "Özbekça Klassik (Xattot)";', strings)
        self.assertIn('"Test Two" = "Test Two Display";', strings)

    def test_hash_changes_with_any_layout(self) -> None:
        first = BundledLayout("Uzbek Latin", "Özbekça Klassik (Xattot)", "<a/>")
        before = _info(_write([first, BundledLayout("Test Two", "Test Two", "<b/>")]))
        after = _info(_write([first, BundledLayout("Test Two", "Test Two", "<c/>")]))
        self.assertNotEqual(before["CFBundleVersion"], after["CFBundleVersion"])


if __name__ == "__main__":
    unittest.main()

"""The bundle carries every layout it is given, and Tugmali keeps its identity."""

from __future__ import annotations

import plistlib
import tempfile
import unittest
from pathlib import Path

from uzkbd.bundle import BundledLayout, source_id, write_bundle
from uzkbd import tugmali
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
    def test_tugmali_identity_is_unchanged(self) -> None:
        expected = "com.sanjarbarakayev.keyboardlayout.xattot.keylayout.UzbekLatinTugmali"
        self.assertEqual(tugmali.NAME, "Uzbek Latin Tugmali")
        self.assertEqual(source_id(tugmali.NAME), expected)

        bundle = _write([BundledLayout(tugmali.NAME, "Özbekça Tugmali (Xattot)", to_xml(tugmali.build_tugmali()))])
        self.assertEqual(_info(bundle)[f"KLInfo_{tugmali.NAME}"]["TISInputSourceID"], expected)

    def test_a_single_layout_makes_a_complete_bundle(self) -> None:
        bundle = _write([BundledLayout(tugmali.NAME, "Özbekça Tugmali (Xattot)", "<a/>")])
        resources = bundle / "Contents" / "Resources"
        self.assertEqual(sorted(p.name for p in resources.iterdir()), ["Uzbek Latin Tugmali.icns", "Uzbek Latin Tugmali.keylayout", "en.lproj"])
        strings = (resources / "en.lproj" / "InfoPlist.strings").read_text(encoding="utf-8")
        self.assertIn('"Uzbek Latin Tugmali" = "Özbekça Tugmali (Xattot)";', strings)

    def test_each_layout_gets_files_and_info(self) -> None:
        bundle = _write(
            [
                BundledLayout("Uzbek Latin Tugmali", "Özbekça Tugmali (Xattot)", "<a/>"),
                BundledLayout("Test Two", "Test Two Display", "<b/>"),
            ]
        )
        resources = bundle / "Contents" / "Resources"
        info = _info(bundle)
        self.assertEqual(info["CFBundleName"], "Xattot")
        for name in ("Uzbek Latin Tugmali", "Test Two"):
            self.assertTrue((resources / f"{name}.keylayout").exists())
            self.assertEqual((resources / f"{name}.icns").read_bytes(), ICON_BYTES)
            self.assertEqual(info[f"KLInfo_{name}"]["TISInputSourceID"], source_id(name))
        strings = (resources / "en.lproj" / "InfoPlist.strings").read_text(encoding="utf-8")
        self.assertIn('"Uzbek Latin Tugmali" = "Özbekça Tugmali (Xattot)";', strings)
        self.assertIn('"Test Two" = "Test Two Display";', strings)

    def test_hash_changes_with_any_layout(self) -> None:
        first = BundledLayout("Uzbek Latin Tugmali", "Özbekça Tugmali (Xattot)", "<a/>")
        before = _info(_write([first, BundledLayout("Test Two", "Test Two", "<b/>")]))
        after = _info(_write([first, BundledLayout("Test Two", "Test Two", "<c/>")]))
        self.assertNotEqual(before["CFBundleVersion"], after["CFBundleVersion"])


if __name__ == "__main__":
    unittest.main()

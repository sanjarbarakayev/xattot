"""Tugmali for Windows: the same keys as the Mac layout, written as kbd DLL tables."""

from __future__ import annotations

import plistlib
import re
import string
import unittest
from dataclasses import replace
from pathlib import Path

from build_windows import app_version, version_h, version_iss
from uzkbd import tugmali
from uzkbd.keys import PRINTABLE
from uzkbd.windows.c_writer import CAPS, cases, to_cases_h, to_chars_h
from uzkbd.windows.keys import MAC_TO_VK, US
from uzkbd.windows.tugmali import DLL, LANGUAGE, NAME, build_tugmali

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = build_tugmali()
KEYS = {key.vk: key for key in LAYOUT.keys}
US_KEYS = {key.vk: key for key in US}
MAC_LAYERS = {"base": 0, "shift": 1, "altgr": 2, "shift_altgr": 3}
CHANGED = {*tugmali.LETTER_KEYS, tugmali.BACKTICK, tugmali.NINE, tugmali.ZERO, 42}


def key(code: int):
    return KEYS[MAC_TO_VK[code]]


class LetterKeyTest(unittest.TestCase):
    def test_identity(self) -> None:
        self.assertEqual((LAYOUT.name, LAYOUT.dll, LAYOUT.language), (NAME, DLL, LANGUAGE))
        self.assertEqual(NAME, "Özbekça Tugmali (Xattot)")

    def test_new_letters_on_base_and_shift(self) -> None:
        codes = tugmali.LETTER_KEYS
        self.assertEqual([key(code).base for code in codes], list("öğşç"))
        self.assertEqual([key(code).shift for code in codes], list("ÖĞŞÇ"))

    def test_caps_lock_capitalizes_new_letters_only(self) -> None:
        self.assertTrue(all(key(code).caps for code in tugmali.LETTER_KEYS))
        self.assertFalse(key(tugmali.BACKTICK).caps)

    def test_tutuq_key(self) -> None:
        backtick = key(tugmali.BACKTICK)
        self.assertEqual((backtick.base, backtick.shift, backtick.altgr), ("ʼ", "~", "`"))

    def test_displaced_symbols_behind_altgr(self) -> None:
        codes = tugmali.LETTER_KEYS
        self.assertEqual([key(code).altgr for code in codes], list("[];'"))
        self.assertEqual([key(code).shift_altgr for code in codes], list('{}:"'))

    def test_quotes_and_guillemets(self) -> None:
        self.assertEqual([key(code).altgr for code in (tugmali.NINE, tugmali.ZERO)], ["“", "”"])
        self.assertEqual([key(code).shift_altgr for code in (tugmali.NINE, tugmali.ZERO)], ["‘", "’"])
        self.assertEqual((key(42).altgr, key(42).shift_altgr), ("«", "»"))
        self.assertEqual(KEYS["VK_OEM_102"], replace(key(42), vk="VK_OEM_102"))


class MacParityTest(unittest.TestCase):
    def test_us_matches_abc(self) -> None:
        for code, vk in MAC_TO_VK.items():
            with self.subTest(code=code):
                self.assertEqual((US_KEYS[vk].base, US_KEYS[vk].shift), PRINTABLE[code][:2])

    def test_changed_keys_type_what_the_mac_layout_types(self) -> None:
        mac = {
            "base": {**tugmali.LETTER_KEYS, tugmali.BACKTICK: tugmali.TUTUQ},
            "shift": tugmali.CAPITAL_KEYS,
            "altgr": tugmali.ABC_OPTION,
            "shift_altgr": tugmali.ABC_SHIFT_OPTION,
        }
        for column, chars in mac.items():
            for code, ch in chars.items():
                with self.subTest(column=column, code=code):
                    self.assertEqual(getattr(key(code), column), ch)

    def test_other_keys_stay_us(self) -> None:
        changed = {MAC_TO_VK[code] for code in CHANGED} | {"VK_OEM_102"}
        for vk, us_key in US_KEYS.items():
            if vk in changed:
                continue
            with self.subTest(vk=vk):
                self.assertEqual(KEYS[vk], us_key)

    def test_ctrl_shortcuts_stay_us(self) -> None:
        for vk, us_key in US_KEYS.items():
            with self.subTest(vk=vk):
                self.assertEqual((KEYS[vk].ctrl, KEYS[vk].shift_ctrl), (us_key.ctrl, us_key.shift_ctrl))

    def test_every_printable_ascii_is_reachable(self) -> None:
        typed = {ch for k in LAYOUT.keys for ch in (k.base, k.shift, k.altgr, k.shift_altgr) if ch}
        self.assertEqual(set(string.printable) - set("\n\x0b\x0c") - typed, set())


class CWriterTest(unittest.TestCase):
    def test_rows_match_their_table_width(self) -> None:
        source = to_chars_h(LAYOUT)
        for width, body in re.findall(r"VK_TO_WCHARS(\d) aVkToWch\d\[\] = \{(.*?)\n\};", source, re.S):
            for row in re.findall(r"\{ (.*) \}", body):
                with self.subTest(row=row):
                    self.assertEqual(len(re.findall(r"'(?:\\.|[^'])'|[^,\s]+", row)), int(width) + 2)

    def test_numpad_table_comes_last(self) -> None:
        tables = re.findall(r"\(PVK_TO_WCHARS1\)aVkToWch(\d)", to_chars_h(LAYOUT))
        self.assertEqual(tables[-1], "1")
        self.assertEqual(len(tables), len(set(tables)))

    def test_no_dead_keys_or_ligatures(self) -> None:
        source = to_chars_h(LAYOUT)
        self.assertNotIn("WCH_DEAD", source)
        self.assertNotIn("WCH_LGTR", source)

    def test_literals(self) -> None:
        source = to_chars_h(LAYOUT)
        self.assertIn("{ VK_OEM_4, CAPLOK, 0x00f6, 0x00d6, '[', 0x001b, WCH_NONE, '{' }", source)
        self.assertIn("{ VK_OEM_7, CAPLOK, 0x00e7, 0x00c7, '\\'', WCH_NONE, WCH_NONE, '\"' }", source)
        self.assertIn("{ VK_OEM_5, 0, '\\\\', '|', 0x00ab, 0x001c, WCH_NONE, 0x00bb }", source)

    def test_cases_cover_caps_lock(self) -> None:
        found = {(vk, mods): ch for vk, mods, ch in cases(LAYOUT)}
        self.assertEqual(found[("VK_OEM_1", CAPS)], "Ş")
        self.assertEqual(found[("VK_OEM_1", f"{CAPS} | 1")], "ş")
        self.assertEqual(found[("VK_OEM_3", "0")], "ʼ")
        self.assertEqual(found[("VK_OEM_3", "6")], "`")
        self.assertNotIn(("'2'", "3"), found)
        self.assertIn('{ VK_OEM_6, 7, L"\\x007d" }', to_cases_h(LAYOUT))

    def test_every_case_is_one_character(self) -> None:
        for vk, mods, ch in cases(LAYOUT):
            with self.subTest(vk=vk, mods=mods):
                self.assertEqual(len(ch), 1)


class PackageTest(unittest.TestCase):
    def test_names_agree_across_files(self) -> None:
        rc = (ROOT / "windows/kbd/kbduzxt.rc").read_text(encoding="utf-8")
        definition = (ROOT / "windows/kbd/kbduzxt.def").read_text(encoding="utf-8")
        iss = (ROOT / "windows/installer/xattot.iss").read_text(encoding="utf-8-sig")
        self.assertIn(f'1000 "{NAME}"', rc)
        self.assertIn(f'"OriginalFilename", "{DLL}.dll"', rc)
        self.assertIn(f"LIBRARY {DLL.upper()}", definition)
        self.assertIn(f'#define LayoutName "{NAME}"', iss)
        self.assertIn(f"LayoutFile = '{DLL}.dll';", iss)
        self.assertIn(f"LanguageId = '{LANGUAGE:04x}';", iss)

    def test_installer_ships_every_build(self) -> None:
        iss = (ROOT / "windows/installer/xattot.iss").read_text(encoding="utf-8-sig")
        for build, dest in (("x64", "{sys}"), ("arm64", "{sys}"), ("wow64", "{syswow64}")):
            with self.subTest(build=build):
                self.assertIn(f'Source: "{{#Dist}}\\{build}\\{DLL}.dll"; DestDir: "{dest}"', iss)

    def test_version_comes_from_the_app(self) -> None:
        with open(ROOT / "app/Info.plist", "rb") as plist:
            version = plistlib.load(plist)["CFBundleShortVersionString"]
        self.assertEqual(app_version(), version)
        self.assertIn(f'#define XATTOT_VERSION_STR "{version}"', version_h(version))
        self.assertIn("#define XATTOT_VERSION 0,2,0,0", version_h("0.2.0"))
        self.assertIn('#define Version "0.2.0"', version_iss("0.2.0"))

    def test_installer_script_has_bom(self) -> None:
        # Inno Setup reads a script without a BOM in the ANSI code page and garbles Ö and ç.
        self.assertTrue((ROOT / "windows/installer/xattot.iss").read_bytes().startswith(b"\xef\xbb\xbf"))


if __name__ == "__main__":
    unittest.main()

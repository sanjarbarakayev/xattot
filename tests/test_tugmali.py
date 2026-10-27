"""The Tugmali layout: dedicated keys for Ö Ğ Ş Ç, run through the keylayout interpreter."""

from __future__ import annotations

import shutil
import string
import subprocess
import tempfile
import unittest
from pathlib import Path

from uzkbd.keys import PRINTABLE, control_char
from uzkbd.layout import LAYERS, build_layout
from uzkbd.simulator import Simulator, shield
from uzkbd.tugmali import LAYOUT_ID, NAME, build_tugmali
from uzkbd.xml_writer import to_xml

DTD = Path("/System/Library/DTDs/KeyboardLayout.dtd")
XML = to_xml(build_tugmali())
LAYER = {name: index for index, name in enumerate(LAYERS)}

LEFT_BRACKET, RIGHT_BRACKET, SEMICOLON, QUOTE, BACKTICK, NINE, ZERO = 33, 30, 41, 39, 50, 25, 29
LETTER_KEYS = (LEFT_BRACKET, RIGHT_BRACKET, SEMICOLON, QUOTE)
CHANGED = {*LETTER_KEYS, BACKTICK, NINE, ZERO}
SHORTCUT_WHITESPACE = "\t\n\r\x0b\x0c"


def press(layer: str, code: int) -> str:
    sim = Simulator(XML)
    sim.press(LAYER[layer], code)
    sim.flush()
    return sim.text


def pressed(layer: str, codes) -> list:
    return [press(layer, code) for code in codes]


class LetterKeyTest(unittest.TestCase):
    def test_identity(self) -> None:
        self.assertEqual((NAME, LAYOUT_ID), ("Uzbek Latin Tugmali", -20261))
        self.assertEqual((build_tugmali().name, build_tugmali().layout_id), (NAME, LAYOUT_ID))

    def test_new_letters_on_base_shift_caps(self) -> None:
        self.assertEqual(pressed("base", LETTER_KEYS), list("öğşç"))
        self.assertEqual(pressed("shift", LETTER_KEYS), list("ÖĞŞÇ"))
        self.assertEqual(pressed("caps", LETTER_KEYS), list("ÖĞŞÇ"))

    def test_tutuq_key(self) -> None:
        self.assertEqual(press("base", BACKTICK), "ʼ")
        self.assertEqual(press("caps", BACKTICK), "ʼ")
        self.assertEqual(press("shift", BACKTICK), "~")
        self.assertEqual(press("option", BACKTICK), "`")

    def test_displaced_symbols_behind_option(self) -> None:
        self.assertEqual(pressed("option", LETTER_KEYS), list("[];'"))
        self.assertEqual(pressed("caps_option", LETTER_KEYS), list("[];'"))
        self.assertEqual(pressed("shift_option", LETTER_KEYS), list('{}:"'))

    def test_quotes_on_9_and_0(self) -> None:
        self.assertEqual(pressed("option", (NINE, ZERO)), ["“", "”"])
        self.assertEqual(pressed("caps_option", (NINE, ZERO)), ["“", "”"])
        self.assertEqual(pressed("shift_option", (NINE, ZERO)), ["‘", "’"])

    def test_parentheses_stay_on_shift(self) -> None:
        self.assertEqual(pressed("shift", (NINE, ZERO)), ["(", ")"])


class ReachabilityTest(unittest.TestCase):
    def test_every_printable_ascii_is_reachable(self) -> None:
        sim = Simulator(XML)
        visible = {sim._visible(entry) for keymap in sim.keymaps.values() for entry in keymap.values()}
        wanted = set(string.printable) - set(SHORTCUT_WHITESPACE)
        self.assertEqual(wanted - visible, set())

    def test_no_pending_state_without_option(self) -> None:
        for layer in ("base", "shift", "caps"):
            codes = Simulator(XML).keymaps[LAYER[layer]]
            for code in codes:
                with self.subTest(layer=layer, code=code):
                    sim = Simulator(XML)
                    sim.press(LAYER[layer], code)
                    self.assertEqual(sim.state, "none")

    def test_other_keys_match_digraph_abc(self) -> None:
        digraph = Simulator(to_xml(build_layout()))
        tugmali = Simulator(XML)
        for layer in ("command", "control"):
            self.assertEqual(
                tugmali.keymaps[LAYER[layer]].keys(), digraph.keymaps[LAYER[layer]].keys()
            )
            for code, entry in tugmali.keymaps[LAYER[layer]].items():
                with self.subTest(layer=layer, code=code):
                    self.assertEqual(entry, digraph.keymaps[LAYER[layer]][code])
        for code, row in PRINTABLE.items():
            if code in CHANGED:
                continue
            with self.subTest(code=code):
                self.assertEqual(tugmali._visible(tugmali.keymaps[LAYER["base"]][code]), row[0])

    def test_shortcuts_stay_abc(self) -> None:
        self.assertEqual(pressed("command", (LEFT_BRACKET, SEMICOLON, QUOTE)), list("[;'"))
        self.assertEqual(press("control", LEFT_BRACKET), "\x1b")
        self.assertEqual(press("control", BACKTICK), control_char("`"))


class AccentTest(unittest.TestCase):
    def compose(self, accent_code: int, letter: str) -> str:
        sim = Simulator(XML)
        sim.press(LAYER["option"], accent_code)
        sim.type(letter)
        sim.flush()
        return sim.text

    def test_accents_still_compose(self) -> None:
        self.assertEqual(self.compose(14, "e"), "é")
        self.assertEqual(self.compose(45, "n"), "ñ")
        self.assertEqual(self.compose(32, "o"), "ö")
        self.assertEqual(self.compose(34, "a"), "â")

    def test_accent_then_space_types_the_accent(self) -> None:
        self.assertEqual(self.compose(14, " "), "´")

    def test_accent_composes_on_caps_and_shift(self) -> None:
        sim = Simulator(XML)
        sim.press(LAYER["option"], 14)
        sim.press(LAYER["shift"], sim.code_for(LAYER["shift"], "E"))
        self.assertEqual(sim.text, "É")

    def test_grave_is_a_plain_backtick(self) -> None:
        sim = Simulator(XML)
        self.assertNotIn("dead_grave", sim.actions)
        self.assertNotIn("grave", sim.terminators)

    def test_every_letter_action_types_its_letter_from_none(self) -> None:
        sim = Simulator(XML)
        for layer in ("base", "shift", "caps"):
            for code, (kind, value) in sim.keymaps[LAYER[layer]].items():
                if kind == "action":
                    with self.subTest(layer=layer, code=code):
                        output, next_state = sim.actions[value]["none"]
                        self.assertIsNotNone(output)
                        self.assertIsNone(next_state)


class XmlTest(unittest.TestCase):
    @unittest.skipUnless(DTD.exists() and shutil.which("xmllint"), "needs macOS DTD and xmllint")
    def test_xml_valid_against_apple_dtd(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".keylayout", encoding="utf-8") as f:
            f.write(shield(XML))
            f.flush()
            result = subprocess.run(
                ["xmllint", "--noout", "--dtdvalid", str(DTD), f.name],
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_every_reference_resolves(self) -> None:
        sim = Simulator(XML)
        for keymap in sim.keymaps.values():
            for kind, value in keymap.values():
                if kind == "action":
                    self.assertIn(value, sim.actions)
        for whens in sim.actions.values():
            for _, next_state in whens.values():
                if next_state:
                    self.assertIn(next_state, sim.terminators)

    def test_header_carries_the_tugmali_id(self) -> None:
        self.assertIn(f'id="{LAYOUT_ID}"', XML)
        self.assertIn(f'name="{NAME}"', XML)


if __name__ == "__main__":
    unittest.main()

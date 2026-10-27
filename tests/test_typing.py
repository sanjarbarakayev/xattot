"""Typing behaviour of the generated layout, run through a keylayout interpreter."""

from __future__ import annotations

import random
import re
import string
import unittest

from uzkbd.layout import LAYERS, build_layout
from uzkbd.simulator import Simulator
from uzkbd.xml_writer import to_xml

XML = to_xml(build_layout())
LAYER = {name: index for index, name in enumerate(LAYERS)}
TRIGGERS = ("ch", "Ch", "CH", "sh", "Sh", "SH", "o'", "O'", "g'", "G'", "o`", "O`", "g`", "G`")
INNER_APOSTROPHE = re.compile(r"[A-Za-z]'[A-Za-z]")


def typed(text: str) -> str:
    sim = Simulator(XML)
    sim.type(text)
    sim.flush()
    return sim.text


class DigraphTest(unittest.TestCase):
    def test_lowercase_digraphs(self) -> None:
        self.assertEqual(typed("choy"), "çoy")
        self.assertEqual(typed("shahar"), "şahar")
        self.assertEqual(typed("o'zbek"), "özbek")
        self.assertEqual(typed("g'isht"), "ğişt")

    def test_backtick_works_like_apostrophe(self) -> None:
        self.assertEqual(typed("o`rik g`oz"), "örik ğoz")

    def test_capitalised_and_all_caps(self) -> None:
        self.assertEqual(typed("Choy Shahar O'zbek G'isht"), "Çoy Şahar Özbek Ğişt")
        self.assertEqual(typed("CHOY SHAHAR"), "ÇOY ŞAHAR")

    def test_sentence(self) -> None:
        self.assertEqual(
            typed("Toshkent shahrida o'qish boshlandi, choy ichdik."),
            "Toşkent şahrida öqiş boşlandi, çoy içdik.",
        )

    def test_letters_that_open_no_digraph_pass_through(self) -> None:
        self.assertEqual(typed("osmon gul og'ir sabr"), "osmon gul oğir sabr")
        self.assertEqual(typed("ssh oo' gg'"), "sş oö gğ")

    def test_pending_letter_is_typed_on_flush(self) -> None:
        self.assertEqual(typed("ras"), "ras")
        self.assertEqual(typed("o"), "o")

    def test_output_uses_the_law_codepoints(self) -> None:
        self.assertEqual(
            [f"U+{ord(c):04X}" for c in typed("ch sh g' o' CH SH G' O'").split()],
            ["U+00E7", "U+015F", "U+011F", "U+00F6", "U+00C7", "U+015E", "U+011E", "U+00D6"],
        )

    def test_text_without_triggers_is_unchanged(self) -> None:
        rng = random.Random(2026)
        alphabet = string.ascii_letters + string.digits + string.punctuation + " "
        checked = 0
        while checked < 300:
            sample = "".join(rng.choice(alphabet) for _ in range(40))
            if any(t in sample for t in TRIGGERS) or INNER_APOSTROPHE.search(sample):
                continue
            self.assertEqual(typed(sample), sample)
            checked += 1


class ForeignWordTest(unittest.TestCase):
    def test_w_keeps_the_rest_of_the_word(self) -> None:
        self.assertEqual(typed("wish watch switch show-off"), "wish watch switch şow-off")
        self.assertEqual(typed("Wish WISH Watch WATCH"), "Wish WISH Watch WATCH")

    def test_c_without_h_keeps_the_rest_of_the_word(self) -> None:
        self.assertEqual(typed("cash code cache accept"), "cash code cache accept")
        self.assertEqual(typed("Cash CASH macOS Facebook"), "Cash CASH macOS Facebook")

    def test_digraphs_return_after_the_word(self) -> None:
        self.assertEqual(typed("wish shahar"), "wish şahar")
        self.assertEqual(typed("cash,choy.wow\rshu"), "cash,çoy.wow\rşu")
        self.assertEqual(typed("code o'qish"), "code öqiş")

    def test_words_with_ch_stay_uzbek(self) -> None:
        self.assertEqual(typed("choyxona shaxmat"), "çoyxona şaxmat")

    def test_english_without_w_or_c_still_joins(self) -> None:
        # Nothing in push or shop says English; Option+H covers them.
        self.assertEqual(typed("push shop"), "puş şop")

    def test_contraction_inside_a_foreign_word(self) -> None:
        self.assertEqual(typed("won't wouldn't"), "won't wouldn't")


class TutuqTest(unittest.TestCase):
    def test_apostrophe_inside_a_word_is_tutuq(self) -> None:
        self.assertEqual(typed("san'at ma'no Qur'on"), "sanʼat maʼno Qurʼon")
        self.assertEqual(typed("SAN'AT"), "SANʼAT")

    def test_apostrophe_after_a_pending_letter(self) -> None:
        self.assertEqual(typed("mas'ul ta'sir"), "masʼul taʼsir")

    def test_digraph_right_after_tutuq(self) -> None:
        self.assertEqual(typed("ta'shkil sa'o'lat"), "taʼşkil saʼölat")

    def test_o_and_g_apostrophe_stay_letters(self) -> None:
        self.assertEqual(typed("o'zbek tog' bog'cha"), "özbek toğ boğça")

    def test_quotes_around_words_stay_apostrophes(self) -> None:
        self.assertEqual(typed("'salom' dedi"), "'salom' dedi")
        self.assertEqual(typed("kitob'."), "kitob'.")

    def test_tutuq_code_point(self) -> None:
        tutuq = typed("a'b")[1]
        self.assertEqual(f"U+{ord(tutuq):04X}", "U+02BC")

    def test_foreign_words_keep_their_apostrophe(self) -> None:
        self.assertEqual(typed("won't"), "won't")

    def test_english_contraction_without_w_or_c_gets_tutuq(self) -> None:
        # Nothing marks it English; the person accepted this trade-off.
        self.assertEqual(typed("don't"), "donʼt")


class OptionLayerTest(unittest.TestCase):
    def press(self, sim: Simulator, layer: str, char: str) -> None:
        sim.press(LAYER[layer], sim.code_for(LAYER[layer], char))

    def test_option_h_escapes_a_digraph(self) -> None:
        sim = Simulator(XML)
        sim.type("pus")
        self.press(sim, "option", "h")
        sim.type(" Chrome")
        sim.flush()
        self.assertEqual(sim.text, "push Çrome")

    def test_option_apostrophe_types_tutuq_and_keeps_the_o(self) -> None:
        sim = Simulator(XML)
        sim.type("mo")
        self.press(sim, "option", "ʼ")
        sim.flush()
        self.assertEqual(sim.text, "moʼ")

    def test_option_types_the_new_letters_directly(self) -> None:
        sim = Simulator(XML)
        for char in "çşğö":
            self.press(sim, "option", char)
        for char in "ÇŞĞÖ":
            self.press(sim, "shift_option", char)
        self.assertEqual(sim.text, "çşğöÇŞĞÖ")

    def test_abc_accent_dead_keys_still_work(self) -> None:
        sim = Simulator(XML)
        self.press(sim, "option", "¨")
        sim.type("o")
        self.press(sim, "option", "´")
        sim.type("e")
        self.press(sim, "option", "´")
        sim.type(" ")
        self.assertEqual(sim.text, "öé´")


class ShortcutLayerTest(unittest.TestCase):
    def test_command_layer_has_no_dead_keys(self) -> None:
        sim = Simulator(XML)
        self.assertFalse(sim.has_actions(LAYER["command"]))

    def test_control_c_is_etx(self) -> None:
        sim = Simulator(XML)
        sim.press(LAYER["control"], 8)
        self.assertEqual(sim.text, "\x03")

    def test_return_after_pending_letter_types_both(self) -> None:
        sim = Simulator(XML)
        sim.type("c")
        sim.press(LAYER["base"], 36)
        self.assertEqual(sim.text, "c\r")


if __name__ == "__main__":
    unittest.main()

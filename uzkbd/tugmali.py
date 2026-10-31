"""Tugmali layout: Ö Ğ Ş Ç on keys of their own, ABC everywhere else."""

from __future__ import annotations

from .keys import KEYPAD, PRINTABLE, SPECIAL, control_char
from .layout import (
    LAYERS,
    LIVE_LAYERS,
    Key,
    Layout,
    Whens,
    accent_actions,
    accent_key,
    accent_terminators,
    accent_transitions,
    action_id,
    is_ascii_letter,
)
from .rules import ACCENTS, TUTUQ

NAME = "Uzbek Latin Tugmali"
LAYOUT_ID = -20261

# Key codes of [ ] ; ' ` 9 0 on ANSI keyboards.
LEFT_BRACKET, RIGHT_BRACKET, SEMICOLON, QUOTE, BACKTICK, NINE, ZERO = 33, 30, 41, 39, 50, 25, 29

LETTER_KEYS = {LEFT_BRACKET: "ö", RIGHT_BRACKET: "ğ", SEMICOLON: "ş", QUOTE: "ç"}
CAPITAL_KEYS = {code: ch.upper() for code, ch in LETTER_KEYS.items()}
# The displaced ABC symbols, reached with Option; 9 and 0 give up ª º and gain the quotes.
ABC_OPTION = {LEFT_BRACKET: "[", RIGHT_BRACKET: "]", SEMICOLON: ";", QUOTE: "'", BACKTICK: "`", NINE: "“", ZERO: "”"}
ABC_SHIFT_OPTION = {LEFT_BRACKET: "{", RIGHT_BRACKET: "}", SEMICOLON: ":", QUOTE: '"', NINE: "‘", ZERO: "’"}

# Option+` types a plain backtick here, so ABC's dead grave is dropped.
ACCENT_KEYS = {code: accent for code, accent in ACCENTS.items() if code != BACKTICK}


def build_tugmali() -> Layout:
    chars = _layer_chars()
    live = {ch for layer in LIVE_LAYERS for ch in chars[layer].values()}
    transitions = accent_transitions(live, ACCENT_KEYS)
    char_actions = {ch: w for ch in sorted(live) if (w := _accent_whens(ch, transitions))}
    layers = {
        layer: tuple(_key(layer, code, ch, char_actions) for code, ch in sorted(chars[layer].items()))
        for layer in LAYERS
    }
    return Layout(
        name=NAME,
        layout_id=LAYOUT_ID,
        layers=layers,
        actions={**{action_id(ch): w for ch, w in char_actions.items()}, **accent_actions(ACCENT_KEYS)},
        terminators=accent_terminators(ACCENT_KEYS),
    )


def _layer_chars() -> dict[str, dict[int, str]]:
    base = {code: row[0] for code, row in PRINTABLE.items()}
    shift = {code: row[1] for code, row in PRINTABLE.items()}
    option = {**{code: row[2] for code, row in PRINTABLE.items()}, **ABC_OPTION}
    layers = {
        "base": {**base, **LETTER_KEYS, BACKTICK: TUTUQ},
        "shift": {**shift, **CAPITAL_KEYS},
        "caps": {
            **{code: ch.upper() if is_ascii_letter(ch) else ch for code, ch in base.items()},
            **CAPITAL_KEYS,
            BACKTICK: TUTUQ,
        },
        "option": option,
        "shift_option": {**{code: row[3] for code, row in PRINTABLE.items()}, **ABC_SHIFT_OPTION},
        "caps_option": option,
        "command": base,
        "control": {code: control_char(ch) for code, ch in base.items()},
    }
    return {layer: {**chars, **KEYPAD, **SPECIAL} for layer, chars in layers.items()}


def _accent_whens(ch: str, transitions: dict[str, dict[str, str]]) -> Whens | None:
    follows: Whens = {state: (rules[ch], None) for state, rules in transitions.items() if ch in rules}
    return {"none": (ch, None), **follows} if follows else None


def _key(layer: str, code: int, ch: str, char_actions: dict[str, Whens]) -> Key:
    if layer in LIVE_LAYERS and ch in char_actions:
        return Key(code, action=action_id(ch))
    return accent_key(layer, code, ACCENT_KEYS) or Key(code, output=ch)

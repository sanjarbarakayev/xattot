"""Layout model: modifier layers of keys, dead-key actions and their terminators."""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from typing import Dict, Optional, Tuple

from .keys import KEYPAD, PRINTABLE, SPECIAL, control_char
from .rules import (
    ACCENTS,
    APOSTROPHE,
    DIGRAPHS,
    FOREIGN,
    FOREIGN_AFTER,
    FOREIGN_LETTERS,
    OPTION_LETTERS,
    TUTUQ,
    WORD,
)

NAME = "Uzbek Latin"
LAYOUT_ID = -20260

# Layer -> modifier combination, in the order macOS matches them.
LAYERS: Dict[str, str] = {
    "base": "",
    "shift": "anyShift caps?",
    "caps": "caps",
    "option": "anyOption",
    "shift_option": "anyShift caps? anyOption",
    "caps_option": "caps anyOption",
    "command": "anyShift? caps? anyOption? anyControl? command",
    "control": "anyShift? caps? anyOption? anyControl",
}

# Only plain typing joins digraphs; Command and Control stay dead-key free for shortcuts.
LIVE_LAYERS = ("base", "shift", "caps")
ACCENT_LAYERS = ("option", "caps_option")

# state -> (output, next state); either may be None, and both together type and move on.
When = Tuple[Optional[str], Optional[str]]
Whens = Dict[str, When]


@dataclass(frozen=True)
class Key:
    code: int
    output: Optional[str] = None
    action: Optional[str] = None


@dataclass(frozen=True)
class Layout:
    name: str
    layout_id: int
    layers: Dict[str, Tuple[Key, ...]]
    actions: Dict[str, Whens]
    terminators: Dict[str, str]


def build_layout() -> Layout:
    chars = _layer_chars()
    live = {ch for layer in LIVE_LAYERS for ch in chars[layer].values()}
    transitions = _transitions(live)
    char_actions = {ch: w for ch in sorted(live) if (w := _char_whens(ch, transitions))}
    accent_actions = {_dead_id(state): {"none": (None, state)} for state, _, _ in ACCENTS.values()}
    layers = {
        layer: tuple(_key(layer, code, ch, char_actions) for code, ch in sorted(chars[layer].items()))
        for layer in LAYERS
    }
    return Layout(
        name=NAME,
        layout_id=LAYOUT_ID,
        layers=layers,
        actions={**{_action_id(ch): w for ch, w in char_actions.items()}, **accent_actions},
        terminators={
            **{state: state for state in DIGRAPHS},
            FOREIGN: "",
            WORD: "",
            APOSTROPHE: "'",
            **{state: spacing for state, _, spacing in ACCENTS.values()},
        },
    )


def _layer_chars() -> Dict[str, Dict[int, str]]:
    base = {code: row[0] for code, row in PRINTABLE.items()}
    option = {code: row[2] for code, row in PRINTABLE.items()}
    lower_option = {code: pair[0] for code, pair in OPTION_LETTERS.items()}
    upper_option = {code: pair[1] for code, pair in OPTION_LETTERS.items()}
    layers = {
        "base": base,
        "shift": {code: row[1] for code, row in PRINTABLE.items()},
        "caps": {code: ch.upper() if _is_ascii_letter(ch) else ch for code, ch in base.items()},
        "option": {**option, **lower_option},
        "shift_option": {**{code: row[3] for code, row in PRINTABLE.items()}, **upper_option},
        "caps_option": {**option, **upper_option},
        "command": base,
        "control": {code: control_char(ch) for code, ch in base.items()},
    }
    return {layer: {**chars, **KEYPAD, **SPECIAL} for layer, chars in layers.items()}


def _transitions(live: set) -> Dict[str, Dict[str, str]]:
    accents = {
        state: {
            **{
                ch: composed
                for ch in live
                if _is_ascii_letter(ch)
                and len(composed := unicodedata.normalize("NFC", ch + mark)) == 1
            },
            " ": spacing,
        }
        for state, mark, spacing in ACCENTS.values()
    }
    return {**DIGRAPHS, **accents}


def _char_whens(ch: str, transitions: Dict[str, Dict[str, str]]) -> Optional[Whens]:
    follows: Whens = {
        state: (rules[ch], WORD if rules[ch].isalpha() else None)
        for state, rules in transitions.items()
        if ch in rules
    }
    if ch == "'":
        # A digraph that did not form still leaves its letter inside the word: masʼul.
        follows[WORD] = (None, APOSTROPHE)
        follows.update({state: (state, APOSTROPHE) for state in DIGRAPHS if ch not in DIGRAPHS[state]})
    if not _is_ascii_letter(ch):
        return {"none": (ch, None), **follows} if follows else None
    follows.update({state: (state + ch, FOREIGN) for state in FOREIGN_AFTER if ch not in DIGRAPHS[state]})
    if ch in DIGRAPHS:
        start: When = (None, ch)
        after_tutuq: When = (TUTUQ, ch)
    elif ch in FOREIGN_LETTERS:
        start = (ch, FOREIGN)
        after_tutuq = (TUTUQ + ch, FOREIGN)
    else:
        start = (ch, WORD)
        after_tutuq = (TUTUQ + ch, WORD)
    return {"none": start, WORD: start, APOSTROPHE: after_tutuq, FOREIGN: (ch, FOREIGN), **follows}


def _key(layer: str, code: int, ch: str, char_actions: Dict[str, Whens]) -> Key:
    if layer in LIVE_LAYERS and ch in char_actions:
        return Key(code, action=_action_id(ch))
    if layer in ACCENT_LAYERS and code in ACCENTS:
        return Key(code, action=_dead_id(ACCENTS[code][0]))
    return Key(code, output=ch)


def _action_id(ch: str) -> str:
    return f"k{ord(ch):04X}"


def _dead_id(state: str) -> str:
    return f"dead_{state}"


def _is_ascii_letter(ch: str) -> bool:
    return ch.isascii() and ch.isalpha()

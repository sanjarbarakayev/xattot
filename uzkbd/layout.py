"""Layout model: modifier layers of keys, dead-key actions and their terminators."""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass

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
LAYERS: dict[str, str] = {
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
When = tuple[str | None, str | None]
Whens = dict[str, When]
# dead accent state, combining mark, spacing accent.
Accent = tuple[str, str, str]


@dataclass(frozen=True)
class Key:
    code: int
    output: str | None = None
    action: str | None = None


@dataclass(frozen=True)
class Layout:
    name: str
    layout_id: int
    layers: dict[str, tuple[Key, ...]]
    actions: dict[str, Whens]
    terminators: dict[str, str]


def build_layout() -> Layout:
    chars = _layer_chars()
    live = {ch for layer in LIVE_LAYERS for ch in chars[layer].values()}
    transitions = _transitions(live)
    char_actions = {ch: w for ch in sorted(live) if (w := _char_whens(ch, transitions))}
    layers = {
        layer: tuple(_key(layer, code, ch, char_actions) for code, ch in sorted(chars[layer].items()))
        for layer in LAYERS
    }
    return Layout(
        name=NAME,
        layout_id=LAYOUT_ID,
        layers=layers,
        actions={**{action_id(ch): w for ch, w in char_actions.items()}, **accent_actions()},
        terminators={
            **{state: state for state in DIGRAPHS},
            FOREIGN: "",
            WORD: "",
            APOSTROPHE: "'",
            **accent_terminators(),
        },
    )


def _layer_chars() -> dict[str, dict[int, str]]:
    base = {code: row[0] for code, row in PRINTABLE.items()}
    option = {code: row[2] for code, row in PRINTABLE.items()}
    lower_option = {code: pair[0] for code, pair in OPTION_LETTERS.items()}
    upper_option = {code: pair[1] for code, pair in OPTION_LETTERS.items()}
    layers = {
        "base": base,
        "shift": {code: row[1] for code, row in PRINTABLE.items()},
        "caps": {code: ch.upper() if is_ascii_letter(ch) else ch for code, ch in base.items()},
        "option": {**option, **lower_option},
        "shift_option": {**{code: row[3] for code, row in PRINTABLE.items()}, **upper_option},
        "caps_option": {**option, **upper_option},
        "command": base,
        "control": {code: control_char(ch) for code, ch in base.items()},
    }
    return {layer: {**chars, **KEYPAD, **SPECIAL} for layer, chars in layers.items()}


def _transitions(live: set) -> dict[str, dict[str, str]]:
    return {**DIGRAPHS, **accent_transitions(live)}


def accent_transitions(live: set, accents: dict[int, Accent] = ACCENTS) -> dict[str, dict[str, str]]:
    """Dead accent state -> {next char: composed letter}, for the letters typed on live layers."""
    return {
        state: {
            **{
                ch: composed
                for ch in live
                if is_ascii_letter(ch) and len(composed := unicodedata.normalize("NFC", ch + mark)) == 1
            },
            " ": spacing,
        }
        for state, mark, spacing in accents.values()
    }


def accent_actions(accents: dict[int, Accent] = ACCENTS) -> dict[str, Whens]:
    return {dead_id(state): {"none": (None, state)} for state, _, _ in accents.values()}


def _char_whens(ch: str, transitions: dict[str, dict[str, str]]) -> Whens | None:
    follows: Whens = {
        state: (rules[ch], WORD if rules[ch].isalpha() else None) for state, rules in transitions.items() if ch in rules
    }
    if ch == "'":
        # A digraph that did not form still leaves its letter inside the word: masʼul.
        follows[WORD] = (None, APOSTROPHE)
        follows.update({state: (state, APOSTROPHE) for state in DIGRAPHS if ch not in DIGRAPHS[state]})
    if not is_ascii_letter(ch):
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


def _key(layer: str, code: int, ch: str, char_actions: dict[str, Whens]) -> Key:
    if layer in LIVE_LAYERS and ch in char_actions:
        return Key(code, action=action_id(ch))
    return accent_key(layer, code) or Key(code, output=ch)


def accent_terminators(accents: dict[int, Accent] = ACCENTS) -> dict[str, str]:
    return {state: spacing for state, _, spacing in accents.values()}


def accent_key(layer: str, code: int, accents: dict[int, Accent] = ACCENTS) -> Key | None:
    if layer in ACCENT_LAYERS and code in accents:
        return Key(code, action=dead_id(accents[code][0]))
    return None


def action_id(ch: str) -> str:
    return f"k{ord(ch):04X}"


def dead_id(state: str) -> str:
    return f"dead_{state}"


def is_ascii_letter(ch: str) -> bool:
    return ch.isascii() and ch.isalpha()

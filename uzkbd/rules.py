"""Uzbek Latin alphabet rules (law OʻRQ-1184) layered on top of ABC."""

from __future__ import annotations

TUTUQ = "ʼ"

# Dead-key state -> {next char: letter}. A state is named after the letter that
# opened it, which is also what gets typed when the next key matches no rule.
DIGRAPHS: dict[str, dict[str, str]] = {
    "c": {"h": "ç"},
    "C": {"h": "Ç", "H": "Ç"},
    "s": {"h": "ş"},
    "S": {"h": "Ş", "H": "Ş"},
    "o": {"'": "ö", "`": "ö"},
    "O": {"'": "Ö", "`": "Ö"},
    "g": {"'": "ğ", "`": "ğ"},
    "G": {"'": "Ğ", "`": "Ğ"},
}

# The alphabet has no w, and c only in ch: a word holding either is foreign, and the
# rest of it types as is, so wish, cash and code stay intact until the next non-letter.
FOREIGN = "foreign"
FOREIGN_LETTERS = "wW"
FOREIGN_AFTER = ("c", "C")

# A letter leaves the word state, so an apostrophe after it opens a pending tutuq: the next
# letter makes it ʼ (sanʼat), anything else types the plain ' of a closing quote.
WORD = "word"
APOSTROPHE = "apostrophe"

# Option layer code -> (option, shift+option). Option+H types a plain h that
# never completes a digraph: s, Option+H gives "sh" for push, cache, Chrome.
OPTION_LETTERS: dict[int, tuple[str, str]] = {
    8: ("ç", "Ç"),
    1: ("ş", "Ş"),
    5: ("ğ", "Ğ"),
    31: ("ö", "Ö"),
    4: ("h", "H"),
    39: (TUTUQ, TUTUQ),
}

# ABC accent dead keys, kept as they are: option code -> (state, combining mark, spacing accent).
ACCENTS: dict[int, tuple[str, str, str]] = {
    14: ("acute", "́", "´"),
    50: ("grave", "̀", "`"),
    34: ("circumflex", "̂", "ˆ"),
    45: ("tilde", "̃", "˜"),
    32: ("diaeresis", "̈", "¨"),
}

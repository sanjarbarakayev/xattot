"""Tugmali for Windows: the Mac layout's keys on top of US, with AltGr in Option's place."""

from __future__ import annotations

from dataclasses import dataclass, replace

from ..keys import PRINTABLE
from ..rules import TUTUQ
from ..tugmali import ABC_OPTION, ABC_SHIFT_OPTION, BACKTICK, CAPITAL_KEYS, LETTER_KEYS
from .keys import MAC_TO_VK, US, WinKey

NAME = "Özbekça Tugmali (Xattot)"
DLL = "kbduzxt"
LANGUAGE = 0x0443  # Uzbek (Latin, Uzbekistan)

BACKSLASH = 42


@dataclass(frozen=True)
class WinLayout:
    name: str
    dll: str
    language: int
    keys: tuple[WinKey, ...]


def build_tugmali() -> WinLayout:
    changes = _changes()
    keys = tuple(replace(key, **changes.get(key.vk, {})) for key in US)
    return WinLayout(NAME, DLL, LANGUAGE, keys)


def _changes() -> dict[str, dict[str, object]]:
    # US has no AltGr layer, so only the keys Tugmali changes gain one, as the Mac Option layer types them.
    altgr = {**ABC_OPTION, BACKSLASH: PRINTABLE[BACKSLASH][2]}
    shift_altgr = {**ABC_SHIFT_OPTION, BACKTICK: PRINTABLE[BACKTICK][3], BACKSLASH: PRINTABLE[BACKSLASH][3]}
    changes: dict[str, dict[str, object]] = {
        MAC_TO_VK[code]: {"altgr": altgr[code], "shift_altgr": shift_altgr[code]} for code in altgr
    }
    for code, letter in LETTER_KEYS.items():
        changes[MAC_TO_VK[code]].update(base=letter, shift=CAPITAL_KEYS[code], caps=True)
    changes[MAC_TO_VK[BACKTICK]]["base"] = TUTUQ
    # The ISO key next to Left Shift types \ | on US, so it follows the backslash key.
    changes["VK_OEM_102"] = changes[MAC_TO_VK[BACKSLASH]]
    return changes

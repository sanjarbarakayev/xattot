"""The Windows US layout (kbdus) as virtual keys and the characters each shift state types."""

from __future__ import annotations

from dataclasses import dataclass

# Shift states in table column order; KbdTables maps modifier bits to these indices.
COLUMNS = ("base", "shift", "altgr", "ctrl", "shift_ctrl", "shift_altgr")

SHIFT, CTRL, ALT = 1, 2, 4
MODIFIERS: dict[str, int] = {
    "base": 0,
    "shift": SHIFT,
    "altgr": CTRL | ALT,
    "ctrl": CTRL,
    "shift_ctrl": SHIFT | CTRL,
    "shift_altgr": SHIFT | CTRL | ALT,
}


@dataclass(frozen=True)
class WinKey:
    vk: str
    base: str | None
    shift: str | None = None
    altgr: str | None = None
    ctrl: str | None = None
    shift_ctrl: str | None = None
    shift_altgr: str | None = None
    caps: bool = False

    def chars(self) -> tuple[str | None, ...]:
        return tuple(getattr(self, column) for column in COLUMNS)


def _letter(ch: str) -> WinKey:
    return WinKey(f"'{ch.upper()}'", ch, ch.upper(), caps=True)


def _symbol(vk: str, base: str, shift: str, ctrl: str | None = None, shift_ctrl: str | None = None) -> WinKey:
    return WinKey(vk, base, shift, ctrl=ctrl, shift_ctrl=shift_ctrl)


# Same keys, characters and order as kbdus.c; numpad digits stay last for VkKeyScan.
US: tuple[WinKey, ...] = (
    _symbol("VK_OEM_3", "`", "~"),
    *(_symbol(f"'{d}'", d, s) for d, s in zip("1345789", "!#$%&*(", strict=True)),
    _symbol("'0'", "0", ")"),
    _symbol("'2'", "2", "@", shift_ctrl="\x00"),
    _symbol("'6'", "6", "^", shift_ctrl="\x1e"),
    _symbol("VK_OEM_MINUS", "-", "_", shift_ctrl="\x1f"),
    _symbol("VK_OEM_PLUS", "=", "+"),
    *(_letter(ch) for ch in "qwertyuiopasdfghjklzxcvbnm"),
    _symbol("VK_OEM_4", "[", "{", "\x1b"),
    _symbol("VK_OEM_6", "]", "}", "\x1d"),
    _symbol("VK_OEM_5", "\\", "|", "\x1c"),
    _symbol("VK_OEM_102", "\\", "|", "\x1c"),
    _symbol("VK_OEM_1", ";", ":"),
    _symbol("VK_OEM_7", "'", '"'),
    _symbol("VK_OEM_COMMA", ",", "<"),
    _symbol("VK_OEM_PERIOD", ".", ">"),
    _symbol("VK_OEM_2", "/", "?"),
    _symbol("VK_DECIMAL", ".", "."),
    _symbol("VK_TAB", "\t", "\t"),
    _symbol("VK_ADD", "+", "+"),
    _symbol("VK_DIVIDE", "/", "/"),
    _symbol("VK_MULTIPLY", "*", "*"),
    _symbol("VK_SUBTRACT", "-", "-"),
    _symbol("VK_BACK", "\b", "\b", "\x7f"),
    _symbol("VK_ESCAPE", "\x1b", "\x1b", "\x1b"),
    _symbol("VK_RETURN", "\r", "\r", "\n"),
    _symbol("VK_SPACE", " ", " ", " "),
    _symbol("VK_CANCEL", "\x03", "\x03", "\x03"),
    *(WinKey(f"VK_NUMPAD{d}", str(d)) for d in range(10)),
)

# Mac ABC key code -> the Windows virtual key in the same place on an ANSI keyboard.
MAC_TO_VK: dict[int, str] = {
    **{
        code: f"'{ch.upper()}'"
        for code, ch in {
            0: "a",
            1: "s",
            2: "d",
            3: "f",
            4: "h",
            5: "g",
            6: "z",
            7: "x",
            8: "c",
            9: "v",
            11: "b",
            12: "q",
            13: "w",
            14: "e",
            15: "r",
            16: "y",
            17: "t",
            31: "o",
            32: "u",
            34: "i",
            35: "p",
            37: "l",
            38: "j",
            40: "k",
            45: "n",
            46: "m",
        }.items()
    },
    **{
        code: f"'{d}'"
        for code, d in {
            18: "1",
            19: "2",
            20: "3",
            21: "4",
            22: "6",
            23: "5",
            25: "9",
            26: "7",
            28: "8",
            29: "0",
        }.items()
    },
    24: "VK_OEM_PLUS",
    27: "VK_OEM_MINUS",
    30: "VK_OEM_6",
    33: "VK_OEM_4",
    39: "VK_OEM_7",
    41: "VK_OEM_1",
    42: "VK_OEM_5",
    43: "VK_OEM_COMMA",
    44: "VK_OEM_2",
    47: "VK_OEM_PERIOD",
    49: "VK_SPACE",
    50: "VK_OEM_3",
}

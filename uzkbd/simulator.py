"""A .keylayout interpreter that follows macOS dead-key rules, for tests and previews.

When the current state has no rule for a key, macOS types that state's terminator
and then handles the key as if no dead key were pending. This does the same.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from typing import Dict, List, Optional, Tuple

_CHAR_REF = re.compile(r"&#x([0-9A-Fa-f]+);")
# XML 1.0 parsers reject C0 control refs, so they ride in a private-use plane while parsing.
_SHIELD = 0xF0000

Entry = Tuple[str, str]  # ("output" | "action", value)
When = Tuple[Optional[str], Optional[str]]  # (output, next state)


def shield(xml_text: str) -> str:
    def swap(match: re.Match) -> str:
        code = int(match.group(1), 16)
        return f"&#x{_SHIELD + code:X};" if code < 0x20 and code not in (0x9, 0xA, 0xD) else match.group(0)

    return _CHAR_REF.sub(swap, xml_text.replace('version="1.1"', 'version="1.0"', 1))


def _unshield(text: str) -> str:
    return "".join(chr(ord(c) - _SHIELD) if _SHIELD <= ord(c) < _SHIELD + 0x20 else c for c in text)


class Simulator:
    def __init__(self, xml_text: str) -> None:
        root = ET.fromstring(shield(xml_text))
        self.keymaps: Dict[int, Dict[int, Entry]] = {
            int(km.get("index")): {
                int(k.get("code")): ("action", k.get("action"))
                if k.get("action")
                else ("output", _unshield(k.get("output", "")))
                for k in km.iter("key")
            }
            for km in root.iter("keyMap")
        }
        self.actions: Dict[str, Dict[str, When]] = {
            action.get("id"): {
                when.get("state"): (
                    _unshield(when.get("output")) if when.get("output") is not None else None,
                    when.get("next"),
                )
                for when in action.iter("when")
            }
            for action in root.iter("action")
        }
        terminators = root.find("terminators")
        self.terminators: Dict[str, str] = {
            when.get("state"): _unshield(when.get("output", "")) for when in terminators.iter("when")
        }
        self.state = "none"
        self._typed: List[str] = []

    @property
    def text(self) -> str:
        return "".join(self._typed)

    def press(self, layer: int, code: int) -> None:
        kind, value = self.keymaps[layer][code]
        if kind == "output":
            self.flush()
            self._typed.append(value)
            return
        whens = self.actions[value]
        if self.state not in whens:
            self.flush()
        output, next_state = whens[self.state]
        if output is not None:
            self._typed.append(output)
        self.state = next_state or "none"

    def flush(self) -> None:
        if self.state != "none":
            self._typed.append(self.terminators[self.state])
            self.state = "none"

    def type(self, text: str) -> None:
        """Types characters reachable without Option, as a person would on the keyboard."""
        for ch in text:
            layer = next(i for i in (0, 1) if self._has_char(i, ch))
            self.press(layer, self.code_for(layer, ch))

    def code_for(self, layer: int, ch: str) -> int:
        return next(code for code, entry in self.keymaps[layer].items() if self._visible(entry) == ch)

    def has_actions(self, layer: int) -> bool:
        return any(kind == "action" for kind, _ in self.keymaps[layer].values())

    def _has_char(self, layer: int, ch: str) -> bool:
        return any(self._visible(entry) == ch for entry in self.keymaps[layer].values())

    def _visible(self, entry: Entry) -> str:
        kind, value = entry
        if kind == "output":
            return value
        output, next_state = self.actions[value]["none"]
        return output if output is not None else self.terminators[next_state]

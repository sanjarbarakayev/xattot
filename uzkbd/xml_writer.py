"""Serialises a Layout to Apple's .keylayout XML."""

from __future__ import annotations

from typing import List, Optional

from .layout import LAYERS, Key, Layout

DOCTYPE = '<!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">'

# Hardware keyboard type ranges Ukelele uses for a single ANSI map set.
KEYBOARD_TYPES = ((0, 17), (18, 18), (21, 23), (30, 30), (33, 33), (36, 36), (194, 194), (197, 197), (200, 201), (206, 207))

_ESCAPED = set("&<>\"'") | {" "}


def to_xml(layout: Layout) -> str:
    maxout = max(len(text) for text in _all_outputs(layout))
    lines: List[str] = [
        '<?xml version="1.1" encoding="UTF-8"?>',
        DOCTYPE,
        f'<keyboard group="126" id="{layout.layout_id}" name="{esc(layout.name)}" maxout="{maxout}">',
        "  <layouts>",
        *(
            f'    <layout first="{first}" last="{last}" modifiers="Modifiers" mapSet="ANSI"/>'
            for first, last in KEYBOARD_TYPES
        ),
        "  </layouts>",
        '  <modifierMap id="Modifiers" defaultIndex="0">',
        *(
            f'    <keyMapSelect mapIndex="{index}"><modifier keys="{keys}"/></keyMapSelect>'
            for index, keys in enumerate(LAYERS.values())
        ),
        "  </modifierMap>",
        '  <keyMapSet id="ANSI">',
    ]
    for index, layer in enumerate(LAYERS):
        lines.append(f'    <keyMap index="{index}">')
        lines.extend(f"      {_key_xml(key)}" for key in layout.layers[layer])
        lines.append("    </keyMap>")
    lines.append("  </keyMapSet>")
    lines.append("  <actions>")
    for action_id, whens in sorted(layout.actions.items()):
        lines.append(f'    <action id="{action_id}">')
        lines.extend(f"      {_when_xml(state, output, next_state)}" for state, (output, next_state) in whens.items())
        lines.append("    </action>")
    lines.append("  </actions>")
    lines.append("  <terminators>")
    lines.extend(
        f'    <when state="{state}" output="{esc(text)}"/>' for state, text in sorted(layout.terminators.items())
    )
    lines.append("  </terminators>")
    lines.append("</keyboard>")
    return "\n".join(lines) + "\n"


def esc(text: str) -> str:
    """Character references for markup and control codes; the rest stays literal UTF-8."""
    return "".join(f"&#x{ord(c):04X};" if c in _ESCAPED or ord(c) < 0x20 or ord(c) == 0x7F else c for c in text)


def _when_xml(state: str, output: Optional[str], next_state: Optional[str]) -> str:
    attrs = f' output="{esc(output)}"' if output is not None else ""
    attrs += f' next="{next_state}"' if next_state is not None else ""
    return f'<when state="{state}"{attrs}/>'


def _key_xml(key: Key) -> str:
    if key.action is not None:
        return f'<key code="{key.code}" action="{key.action}"/>'
    return f'<key code="{key.code}" output="{esc(key.output or "")}"/>'


def _all_outputs(layout: Layout) -> List[str]:
    keys = [key.output for layer in layout.layers.values() for key in layer if key.output]
    whens = [output for whens in layout.actions.values() for output, _ in whens.values() if output is not None]
    return keys + whens + list(layout.terminators.values())

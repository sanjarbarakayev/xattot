#!/usr/bin/env python3
"""Writes the cross-check corpus: every Swift test input, every parity input and random key
strings, each under every engine configuration. One `config<TAB>notation` line per run."""

from __future__ import annotations

import json
import random
import re
import sys
from pathlib import Path

INPUTMETHOD = Path(__file__).resolve().parents[4] / "inputmethod"
CONFIGS = [
    f"{mode},{lexicon},{stale},{smart}"
    for mode in ("eager", "marked")
    for lexicon in ("none", "small", "bundled")
    for stale in (0, 1)
    for smart in (0, 1)
]
# Openers, their second keys, the foreign triggers, marks, Backspace, option and the named keys.
ALPHABET = list("sShHcCoOgGaiuwW'`\"- x") + ["⌫", "⌥", "↵", "⇥", "⎋", "←", "→", "⌘"]
LITERAL = re.compile(r'typed(?:WithClick)?\("((?:[^"\\]|\\.)*)"')
SWIFT_ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "0": "\0"}


def unescape_swift(literal: str) -> str:
    return re.sub(r"\\(.)", lambda m: SWIFT_ESCAPES.get(m.group(1), m.group(1)), literal)


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t")


def swift_inputs() -> set[str]:
    found = set()
    for path in (INPUTMETHOD / "Tests").glob("*.swift"):
        found.update(unescape_swift(m) for m in LITERAL.findall(path.read_text(encoding="utf-8")))
    return found


def parity_inputs() -> set[str]:
    cases = json.loads((INPUTMETHOD / "Tests" / "parity.json").read_text(encoding="utf-8"))
    return {case["input"] for case in cases}


def random_inputs(count: int) -> set[str]:
    rng = random.Random(1184)
    words = ["shahar", "push", "chap", "o'g'il", "'video'", "don't", "show", "bosh", "`log`", "ma'no", "chrome"]
    found = set()
    while len(found) < count:
        if rng.random() < 0.3:
            text = " ".join(rng.choice(words) for _ in range(rng.randint(1, 3)))
            text = "".join(c if rng.random() > 0.1 else rng.choice(ALPHABET) for c in text)
        else:
            text = "".join(rng.choice(ALPHABET) for _ in range(rng.randint(1, 14)))
        found.add(text)
    return found


def main() -> None:
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
    inputs = sorted(swift_inputs() | parity_inputs() | random_inputs(count))
    for notation in inputs:
        if not notation:
            continue
        for config in CONFIGS:
            print(f"{config}\t{escape(notation)}")


if __name__ == "__main__":
    main()

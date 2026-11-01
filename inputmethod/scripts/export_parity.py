#!/usr/bin/env python3
"""Exports parity data from the layout simulator in this repo (uzkbd).

Reads a clean snapshot of origin/main (never the working tree) and
writes Tests/parity.json, Tests/parity-source.txt and Bench/corpus.txt.
"""

from __future__ import annotations

import ast
import json
import os
import random
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FREE = Path(os.environ.get("XATTOT_FREE") or ROOT.parent)
# The brief's syllables minus the bare w and c (foreign-word triggers); ch stays.
SYLLABLES = ["a", "o", "u", "i", "e", "sh", "ch", "o'", "g'", "s", "g", "n", "t", "r", "k", "m", "'", " ", ","]
GENERATED = 500
CORPUS_WORDS = 10_000


def git(*args: str) -> bytes:
    return subprocess.run(["git", "-C", str(FREE), *args], check=True, capture_output=True).stdout


def literals(test_source: str) -> list[str]:
    """First string literal argument of every typed(...) call."""
    found = []
    for node in ast.walk(ast.parse(test_source)):
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "typed"
            and node.args
            and isinstance(node.args[0], ast.Constant)
            and isinstance(node.args[0].value, str)
        ):
            found.append(node.args[0].value)
    return found


def generated() -> list[str]:
    rng = random.Random(2026)
    return ["".join(rng.choice(SYLLABLES) for _ in range(rng.randint(3, 12))) for _ in range(GENERATED)]


def main() -> None:
    sha = git("rev-parse", "origin/main").decode().strip()
    with tempfile.TemporaryDirectory() as tmp:
        snapshot = Path(tmp) / "snapshot"
        snapshot.mkdir()
        subprocess.run(["tar", "-x", "-C", str(snapshot)], input=git("archive", "origin/main"), check=True)
        sys.path.insert(0, str(snapshot))
        from uzkbd.layout import build_layout
        from uzkbd.simulator import Simulator
        from uzkbd.xml_writer import to_xml

        xml = to_xml(build_layout())
        inputs = sorted(set(literals((snapshot / "tests" / "test_typing.py").read_text()) + generated()))

        def free_output(text: str) -> str:
            sim = Simulator(xml)
            sim.type(text)
            sim.flush()
            return sim.text

        cases = [{"input": text, "output": free_output(text)} for text in inputs]

    (ROOT / "Tests" / "parity.json").write_text(json.dumps(cases, ensure_ascii=False, indent=1) + "\n")
    (ROOT / "Tests" / "parity-source.txt").write_text(sha + "\n")

    # Synthetic bench corpus: words of the parity inputs (random syllables and test literals), not real Uzbek text.
    words = [w for text in inputs for w in text.split()]
    corpus = [words[i % len(words)] for i in range(CORPUS_WORDS)]
    lines = [" ".join(corpus[i : i + 12]) for i in range(0, CORPUS_WORDS, 12)]
    (ROOT / "Bench").mkdir(exist_ok=True)
    (ROOT / "Bench" / "corpus.txt").write_text("\n".join(lines) + "\n")
    print(f"{len(cases)} cases from {sha[:9]}")


if __name__ == "__main__":
    main()

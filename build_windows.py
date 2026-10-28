#!/usr/bin/env python3
"""Writes the generated C headers windows/build.bat compiles into the Tugmali DLL and its typing test."""

from __future__ import annotations

from pathlib import Path

from uzkbd.windows.c_writer import to_cases_h, to_chars_h
from uzkbd.windows.tugmali import build_tugmali

ROOT = Path(__file__).resolve().parent


def main() -> None:
    out = ROOT / "dist" / "windows" / "gen"
    out.mkdir(parents=True, exist_ok=True)
    layout = build_tugmali()
    (out / "chars.h").write_text(to_chars_h(layout), encoding="ascii")
    (out / "cases.h").write_text(to_cases_h(layout), encoding="ascii")
    print(out)


if __name__ == "__main__":
    main()

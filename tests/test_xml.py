"""Structural checks on the generated keylayout XML."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from uzkbd.layout import build_layout
from uzkbd.simulator import Simulator, shield
from uzkbd.xml_writer import to_xml

DTD = Path("/System/Library/DTDs/KeyboardLayout.dtd")
XML = to_xml(build_layout())


class XmlTest(unittest.TestCase):
    @unittest.skipUnless(DTD.exists() and shutil.which("xmllint"), "needs macOS DTD and xmllint")
    def test_valid_against_apple_dtd(self) -> None:
        # libxml2 only reads XML 1.0, so control-character refs are shielded first.
        with tempfile.NamedTemporaryFile("w", suffix=".keylayout", encoding="utf-8") as f:
            f.write(shield(XML))
            f.flush()
            result = subprocess.run(
                ["xmllint", "--noout", "--dtdvalid", str(DTD), f.name],
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_every_reference_resolves(self) -> None:
        sim = Simulator(XML)
        for keymap in sim.keymaps.values():
            for kind, value in keymap.values():
                if kind == "action":
                    self.assertIn(value, sim.actions)
        for whens in sim.actions.values():
            for kind, value in whens.values():
                if kind == "next":
                    self.assertIn(value, sim.terminators)

    def test_header_declares_unicode_custom_layout(self) -> None:
        self.assertTrue(XML.startswith('<?xml version="1.1" encoding="UTF-8"?>'))
        self.assertIn('group="126"', XML)
        self.assertIn('id="-20260"', XML)


if __name__ == "__main__":
    unittest.main()

"""The release job's rewrite of the Homebrew cask: version and checksum, nothing else."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "update_cask.py"
_spec = importlib.util.spec_from_file_location("update_cask", SCRIPT)
update_cask = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(update_cask)

OLD_SHA = "e12e13273b56e525080ac98e129c87aba4debc0c5509f951074add3ce51ae0c9"
NEW_SHA = "0" * 62 + "ab"
CASK = f'''cask "xattot" do
  version "0.3.0"
  sha256 "{OLD_SHA}"

  url "https://github.com/sanjarbarakayev/xattot/releases/download/v#{{version}}/Xattot.dmg"
  name "Xattot"
end
'''


class UpdateCaskTest(unittest.TestCase):
    def test_replaces_version_and_checksum_only(self) -> None:
        updated = update_cask.update(CASK, "0.4.0", NEW_SHA)
        self.assertEqual(
            updated,
            CASK.replace('version "0.3.0"', 'version "0.4.0"').replace(OLD_SHA, NEW_SHA),
        )

    def test_same_release_leaves_the_cask_unchanged(self) -> None:
        self.assertEqual(update_cask.update(CASK, "0.3.0", OLD_SHA), CASK)

    def test_rejects_a_version_that_is_not_dotted_numbers(self) -> None:
        for version in ("v0.4.0", "0.4", "0.4.0-beta", '0.4.0"'):
            with self.subTest(version=version), self.assertRaises(ValueError):
                update_cask.update(CASK, version, NEW_SHA)

    def test_rejects_a_checksum_that_is_not_sha256_hex(self) -> None:
        for sha in ("", NEW_SHA[:-1], NEW_SHA.upper(), NEW_SHA[:-1] + "g"):
            with self.subTest(sha=sha), self.assertRaises(ValueError):
                update_cask.update(CASK, "0.4.0", sha)

    def test_rejects_a_cask_without_exactly_one_stanza_each(self) -> None:
        for cask in (CASK.replace('  version "0.3.0"\n', ""), CASK + f'  sha256 "{OLD_SHA}"\n'):
            with self.subTest(cask=cask), self.assertRaises(ValueError):
                update_cask.update(cask, "0.4.0", NEW_SHA)

    def test_command_line_rewrites_the_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "xattot.rb"
            path.write_text(CASK, encoding="utf-8")
            subprocess.run([sys.executable, str(SCRIPT), str(path), "0.4.0", NEW_SHA], check=True)
            self.assertIn('version "0.4.0"', path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()

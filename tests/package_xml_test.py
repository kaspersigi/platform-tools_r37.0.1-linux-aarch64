#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(PROJECT_ROOT / "scripts/check-package-xml.py"))
validate_package_xml = MODULE["validate_package_xml"]


class PackageXmlTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary_directory.name) / "package.xml"
        subprocess.run(
            [str(PROJECT_ROOT / "scripts/render-package-xml.sh"), str(self.path)],
            check=True,
        )

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_rendered_metadata_is_valid(self) -> None:
        self.assertEqual(validate_package_xml(self.path, "37.0.1"), [])

    def test_empty_metadata_is_rejected(self) -> None:
        self.path.write_bytes(b"")
        self.assertTrue(validate_package_xml(self.path, "37.0.1"))

    def test_wrong_revision_is_rejected(self) -> None:
        content = self.path.read_text(encoding="utf-8")
        self.path.write_text(
            content.replace("<micro>1</micro>", "<micro>2</micro>"),
            encoding="utf-8",
        )
        errors = validate_package_xml(self.path, "37.0.1")
        self.assertTrue(any("revision differs" in error for error in errors))


if __name__ == "__main__":
    unittest.main()

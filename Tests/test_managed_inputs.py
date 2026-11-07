# SPDX-License-Identifier: GPL-3.0-only
"""Reject stale or corrupted own CI payloads without requiring any game files."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "script"))
import managed


class ManagedInputsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "Trainer.cs").write_text("// Test-only source fixture\n")
        self.manifest = {"id": "fixture", "profiles": [{"id": "test", "uuid": "original"}]}
        self.config = {"managed": {"referenceProfile": "test", "sources": ["Trainer.cs"]}}
        self.data = b"Test-only compiled-image fixture"
        (self.root / "fixture.Managed.dll").write_bytes(self.data)
        self.lock = self.root / "lock.json"
        self.write_lock()
        context = patch.object(managed, "MANAGED_LOCK", self.lock)
        context.start()
        self.addCleanup(context.stop)

    def write_lock(self, filename="fixture.Managed.dll"):
        self.lock.write_text(json.dumps({"schemaVersion": 1, "modules": {"fixture": {
            "file": filename, "sha256": hashlib.sha256(self.data).hexdigest(),
            "sourceSha256": managed.managed_source_hash(self.root, self.manifest, self.config)}}}))

    def read(self):
        return managed.verified_managed_image(self.root, self.root, self.manifest, self.config)

    def test_exact_payload_is_accepted(self):
        self.assertEqual(self.read(), self.data)

    def test_changed_source_is_rejected(self):
        (self.root / "Trainer.cs").write_text("// changed fixture\n")
        with self.assertRaisesRegex(ValueError, "Quellen/Originalbindung"):
            self.read()

    def test_changed_original_identity_is_rejected(self):
        self.manifest["profiles"][0]["uuid"] = "different"
        with self.assertRaisesRegex(ValueError, "Quellen/Originalbindung"):
            self.read()

    def test_changed_payload_is_rejected(self):
        (self.root / "fixture.Managed.dll").write_bytes(b"corrupted")
        with self.assertRaisesRegex(ValueError, "Hash"):
            self.read()

    def test_traversal_is_rejected(self):
        self.write_lock("../fixture.Managed.dll")
        with self.assertRaisesRegex(ValueError, "Bausteinpfad"):
            self.read()


if __name__ == "__main__":
    unittest.main()

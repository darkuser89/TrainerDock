#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Synthetic fixtures only. No Epic client, installed game, manifests or saves."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

spec = importlib.util.spec_from_file_location("epic_probe", Path(__file__).with_name("controller.py"))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class Transactions(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="trainerdock-epic-fixture-", dir="/private/tmp")
        self.root = Path(self.temp.name).resolve()
        self.install = self.root / "install"
        self.install.mkdir()
        self.target = self.install / "Fixture.app/Contents/MacOS/Fixture"
        self.target.parent.mkdir(parents=True)
        self.target.write_bytes(b"fixture-original")
        self.target.chmod(0o700)
        self.manifest = self.root / "fixture.item"
        self.item = dict(AppName="fixture-app", CatalogNamespace="fixture-namespace", CatalogItemId="fixture-item",
                         InstallLocation=str(self.install), LaunchExecutable="Fixture.app/Contents/MacOS/Fixture", LaunchCommand="", Extra="retained")
        self.original = json.dumps(self.item, indent=3).encode() + b"\n"
        self.manifest.write_bytes(self.original)
        self.approved = dict(manifest=str(self.manifest), appName="fixture-app", namespace="fixture-namespace", install=str(self.install),
                             launchExecutable=self.item["LaunchExecutable"], targetSHA256=probe.digest(self.target))
        self.launch = dict(target=str(self.target), environment={"MHT_TARGET": str(self.target), "DYLD_INSERT_LIBRARIES": "/private/tmp/own-fixture.dylib"})

    def tearDown(self):
        self.temp.cleanup()

    def journal(self):
        broker, sidecar, receipt = self.install / "own-broker", self.install / "own-broker.json", self.root / "receipt.json"
        broker.write_bytes(b"own-broker"); sidecar.write_bytes(b"own-config")
        changed = probe.replace_string(self.original, "LaunchExecutable", broker.name)
        journal = dict(manifest=str(self.manifest), original=probe.base64.b64encode(self.original).decode(),
                       changed=probe.base64.b64encode(changed).decode(), mode=0o600,
                       broker=str(broker), sidecar=str(sidecar), receipt=str(receipt),
                       brokerSHA256=probe.digest(broker), sidecarSHA256=probe.digest(sidecar))
        path = self.root / "transaction.json"
        probe.atomic(path, probe.encode(journal))
        self.manifest.write_bytes(changed)
        return path, journal

    def test_exact_identity_and_individual_fields(self):
        self.assertEqual(probe.validate(self.approved, self.launch), (self.original, self.target))
        for key in ("AppName", "CatalogNamespace", "InstallLocation", "LaunchExecutable", "LaunchCommand"):
            item = dict(self.item, **{key: "different"})
            self.manifest.write_bytes(probe.encode(item))
            with self.assertRaises(ValueError):
                probe.validate(self.approved, self.launch)
        self.manifest.write_bytes(self.original)
        self.target.write_bytes(b"changed")
        with self.assertRaises(ValueError):
            probe.validate(self.approved, self.launch)

    def test_only_exact_json_string_changes(self):
        data = b' \n{ "Nested":{"LaunchExecutable":"keep"}, "LaunchExecutable" : "old\\u002fpath", "Other" : [1,2] }\n'
        expected = data.replace(b'"old\\u002fpath"', b'"own-broker"')
        self.assertEqual(probe.replace_string(data, "LaunchExecutable", "own-broker"), expected)
        with self.assertRaises(ValueError):
            probe.replace_string(b'{"LaunchExecutable":"a","LaunchExecutable":"b"}', "LaunchExecutable", "own")

    def test_rollback_restores_exact_original_bytes(self):
        path, journal = self.journal()
        probe.recover(path, lambda: {})
        self.assertEqual(self.manifest.read_bytes(), self.original)
        self.assertFalse(path.exists())
        self.assertFalse(Path(journal["broker"]).exists())
        self.assertFalse(Path(journal["sidecar"]).exists())

    def test_cli_recovery_cannot_interrupt_active_transaction(self):
        path, journal = self.journal()
        before = self.manifest.read_bytes()
        lock = os.open(self.root / "lock", os.O_CREAT | os.O_RDWR, 0o600)
        try:
            probe.fcntl.flock(lock, probe.fcntl.LOCK_EX | probe.fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):
                probe.recover_cli(path)
            self.assertEqual(self.manifest.read_bytes(), before)
            self.assertTrue(path.exists())
            self.assertTrue(Path(journal["broker"]).exists())
        finally:
            os.close(lock)

    def test_newer_external_manifest_is_never_overwritten(self):
        path, journal = self.journal()
        external = probe.encode(dict(self.item, Extra="newer Epic metadata"))
        self.manifest.write_bytes(external)
        with self.assertRaises(ValueError):
            probe.recover(path, lambda: {})
        self.assertEqual(self.manifest.read_bytes(), external)
        self.assertTrue(path.exists())
        self.assertTrue(Path(journal["broker"]).exists())

    def test_loaded_broker_preserved_but_manifest_restored(self):
        path, journal = self.journal()
        with self.assertRaises(ValueError):
            probe.recover(path, lambda: {123: journal["broker"]})
        self.assertEqual(self.manifest.read_bytes(), self.original)
        self.assertTrue(path.exists())
        self.assertTrue(Path(journal["broker"]).exists())
        probe.recover(path, lambda: {})
        self.assertFalse(path.exists())

    def test_modified_probe_is_preserved(self):
        path, journal = self.journal()
        Path(journal["broker"]).write_bytes(b"external")
        with self.assertRaises(ValueError):
            probe.recover(path, lambda: {})
        self.assertEqual(Path(journal["broker"]).read_bytes(), b"external")

    def test_private_files_and_symlinks(self):
        config = self.root / "private.json"
        config.write_bytes(b"{}")
        config.chmod(0o644)
        with self.assertRaises(ValueError):
            probe.read(config, private=True)
        config.chmod(0o600)
        self.assertEqual(probe.read(config, private=True), b"{}")
        link = self.root / "link.json"
        link.symlink_to(config)
        with self.assertRaises(OSError):
            probe.read(link, private=True)

    def test_no_arbitrary_environment_or_cross_target(self):
        for field, value in (("PATH", "/fixture"), ("AUTH_PASSWORD", "fixture-not-a-token")):
            launch = dict(self.launch, environment=dict(self.launch["environment"], **{field: value}))
            with self.assertRaises(ValueError):
                probe.validate(self.approved, launch)
        with self.assertRaises(ValueError):
            probe.validate(self.approved, dict(self.launch, target="/another-target"))

    def test_default_is_plan_without_mutation_or_launch(self):
        approval = self.root / "Spec.json"; launch = self.root / "Launch.json"
        approval.write_bytes(probe.encode(self.approved)); probe.atomic(launch, probe.encode(self.launch))
        result = subprocess.run(["python3", "-B", str(Path(__file__).with_name("controller.py")), "--spec", str(approval), "--config", str(launch), "--broker", "/nonexistent/broker"], capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout)["mode"], "read-only-plan")
        self.assertEqual(self.manifest.read_bytes(), self.original)
        self.assertEqual(sorted(p.name for p in self.install.iterdir()), ["Fixture.app"])
        self.assertNotIn("environment", result.stdout)


class NativeBroker(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("EPIC_TEST_BROKER"), "set EPIC_TEST_BROKER to the own compiled test broker")
    def test_opaque_argv_and_exact_target_environment(self):
        with tempfile.TemporaryDirectory(prefix="trainerdock-epic-native-", dir="/private/tmp") as directory:
            root = Path(directory).resolve(); source = root / "fixture.c"; target = root / "fixture"
            # Fixed synthetic values only. The fixture checks them internally and never writes argv.
            source.write_text('#include <string.h>\n#include <stdlib.h>\nint main(int n,char **v){return n==3&&!strcmp(v[1],"opaque-fixture-one")&&!strcmp(v[2],"value with spaces")&&getenv("MHT_SYNTHETIC")&&!strcmp(getenv("MHT_SYNTHETIC"),"yes")?0:91;}\n')
            subprocess.run(["xcrun", "clang", "-Wall", "-Wextra", "-Werror", str(source), "-o", str(target)], check=True)
            library_source = root / "own.c"; library_source.write_text("void own_synthetic_library(void) {}\n")
            library = root / "own.dylib"
            subprocess.run(["xcrun", "clang", "-dynamiclib", str(library_source), "-o", str(library)], check=True)
            broker = root / "broker"; broker.write_bytes(Path(os.environ["EPIC_TEST_BROKER"]).read_bytes()); broker.chmod(0o700)
            receipt = root / "receipt.json"
            config = dict(target=str(target), targetSHA256=probe.digest(target), receipt=str(receipt), expires=time.time()+30, nonce="synthetic-probe",
                          environment={"MHT_TARGET": str(target), "MHT_SYNTHETIC": "yes", "DYLD_INSERT_LIBRARIES": str(library)})
            probe.atomic(str(broker)+".json", probe.encode(config))
            result = subprocess.run([str(broker), "opaque-fixture-one", "value with spaces"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b""); self.assertEqual(result.stderr, b"")
            self.assertEqual(probe.load(probe.read(receipt))["state"], "exec-attempt")
            self.assertNotIn(b"opaque-fixture", receipt.read_bytes())
            receipt.unlink(); config["targetSHA256"] = "0" * 64; probe.atomic(str(broker)+".json", probe.encode(config))
            result = subprocess.run([str(broker), "opaque-fixture-one", "value with spaces"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(result.returncode, 70)
            self.assertFalse(receipt.exists())
            config["targetSHA256"] = probe.digest(target)
            config["environment"]["MHT_BAD\x00NAME"] = "yes"
            probe.atomic(str(broker)+".json", probe.encode(config))
            self.assertEqual(subprocess.run([str(broker)], stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode, 70)
            self.assertFalse(receipt.exists())
            del config["environment"]["MHT_BAD\x00NAME"]
            insecure = root / "insecure"; insecure.mkdir(mode=0o755); insecure.chmod(0o755)
            config["receipt"] = str(insecure / "receipt.json")
            probe.atomic(str(broker)+".json", probe.encode(config))
            self.assertEqual(subprocess.run([str(broker)], stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode, 70)
            self.assertFalse(Path(config["receipt"]).exists())
            config["receipt"] = str(receipt)
            config["targetSHA256"] = probe.digest(target); config["expires"] = time.time()-1; probe.atomic(str(broker)+".json", probe.encode(config))
            self.assertEqual(subprocess.run([str(broker)], stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode, 70)


if __name__ == "__main__":
    unittest.main()

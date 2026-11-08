# SPDX-License-Identifier: GPL-3.0-only
"""Distribution fixtures never enter a product and do not load game runtimes."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "script"))
import trainer_distribution as distribution


def record(identifier="one", current="1.0.0", fingerprint="a" * 64):
    return dict(version=current, fingerprint=fingerprint,
                url=distribution.BASE_URL + f"trainer-{identifier}-v{current}/{identifier}-{current}.zip",
                sha256="b" * 64, size=10, minimumLauncherVersion="1.0.0", moduleABI=1,
                manifest=dict(id=identifier, name=identifier, version=current,
                              features=[{"id": "health"}], profiles=[{"id": "steam"}]))


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="trainerdock-distribution-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        files = {"ModuleSDK/MHTProtocol.m": '#include "Protocol.h"\n',
                 "ModuleSDK/Protocol.h": "// protocol", "ModuleSDK/Glass.m": "// glass",
                 "Config/TrainerDock.xcconfig": "FRAMEWORKS = AppKit",
                 "Config/Info.plist": "plist", "App/Resources/TrainerDock.png": "icon",
                 "App/Main.m": '#include "Main.h"\n', "App/Main.h": "// main",
                 "Core/Store.m": "// store", "LICENSE": "license",
                 "Modules/_Shared/Shared.h": "// shared"}
        for name in ("build.py", "xcode_project.py", "xcode_support.py", "release.py", "managed.py"):
            files["script/" + name] = "# build infrastructure"
        for path, text in files.items():
            self.write(path, text)
        for identifier in ("one", "two", "three"):
            self.write(f"Modules/{identifier}/Sources/Main.m", '#include "../../../_Shared/Shared.h"\n' if identifier != "three" else "// independent")
            # Relative include from Sources to Modules/_Shared is ../../_Shared.
            if identifier != "three":
                self.write(f"Modules/{identifier}/Sources/Main.m", '#include "../../_Shared/Shared.h"\n')
            self.write(f"Modules/{identifier}/Build.json", json.dumps(dict(sources=["Main.m"], sdkSources=["Glass.m"])))
            self.write(f"Modules/{identifier}/Module.json", json.dumps(dict(id=identifier,name=identifier,version="1.0.0")))
            self.write(f"Modules/{identifier}/Sources/LICENSE", "fixture license")

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)

    def confirmed(self):
        initial = distribution.plan(distribution.empty_catalog(), self.root)
        records = {item["id"]: record(item["id"], item["version"], item["fingerprint"]) for item in initial["modules"]}
        catalog = distribution.merged_catalog(distribution.empty_catalog(), records)
        catalog["launcher"] = dict(version="1.0.0",fingerprint=initial["launcher"]["fingerprint"])
        return catalog

    def changed(self, catalog):
        return distribution.plan(catalog, self.root)

    def test_unchanged_and_launcher_only(self):
        catalog = self.confirmed()
        self.assertEqual(self.changed(catalog)["modules"], [])
        self.assertFalse(self.changed(catalog)["launcher"]["changed"])
        self.write("App/Main.h", "// changed UI")
        updated = self.changed(catalog)
        self.assertEqual(updated["modules"], [])
        self.assertTrue(updated["launcher"]["changed"])

    def test_shared_header_only_rebuilds_actual_dependents(self):
        catalog = self.confirmed()
        self.write("Modules/_Shared/Shared.h", "// changed backend")
        updated = self.changed(catalog)
        self.assertEqual([item["id"] for item in updated["modules"]], ["one", "two"])
        self.assertFalse(updated["launcher"]["changed"])

    def test_sdk_and_actual_flags_rebuild_affected_products(self):
        catalog = self.confirmed()
        self.write("ModuleSDK/Glass.m", "// changed shared renderer")
        updated = self.changed(catalog)
        self.assertEqual(len(updated["modules"]), 3)
        self.assertFalse(updated["launcher"]["changed"])
        self.write("Config/TrainerDock.xcconfig", "FRAMEWORKS = AppKit Metal")
        self.assertTrue(self.changed(catalog)["launcher"]["changed"])

    def test_managed_lock_entries_are_independent(self):
        for identifier in ("one", "two"):
            config = dict(sources=["Main.m"], managed=dict(sources=["Sources/Managed.cs"]))
            self.write(f"Modules/{identifier}/Build.json", json.dumps(config))
            self.write(f"Modules/{identifier}/Sources/Managed.cs", "// managed")
        lock = dict(release="v1", modules=dict(one=dict(sha256="a"),two=dict(sha256="b")))
        self.write("Config/ManagedImages.json", json.dumps(lock))
        catalog = self.confirmed()
        lock["release"] = "v2"
        lock["modules"]["one"]["sha256"] = "c"
        self.write("Config/ManagedImages.json", json.dumps(lock))
        self.assertEqual([item["id"] for item in self.changed(catalog)["modules"]], ["one"])

    def test_test_only_changes_do_not_rebuild_packages(self):
        catalog = self.confirmed()
        self.write("Tests/Contract.m", "// test")
        path = self.root / "Modules/one/Build.json"
        config = json.loads(path.read_text()); config["nativeContractTests"] = ["Tests/Contract.m"]
        path.write_text(json.dumps(config))
        self.assertEqual(self.changed(catalog)["modules"], [])

    def test_versions_preserve_old_and_skip_reserved_tags(self):
        catalog = self.confirmed()
        self.write("Modules/one/Sources/Main.m", "// changed")
        updated = distribution.plan(catalog, self.root, {"one": ["1.0.1", "1.0.2"]})
        self.assertEqual(updated["modules"][0]["version"], "1.0.3")
        merged = distribution.merged_catalog(catalog, {"one": record("one", "1.0.3")})
        self.assertEqual([item["version"] for item in merged["modules"][0]["versions"]], ["1.0.3", "1.0.0"])
        with self.assertRaises(ValueError):
            distribution.merged_catalog(catalog, {"one": record("one", "1.0.0", "f" * 64)})
        for invalid in ("1.0", "01.0.0", "1.0.0-beta", "-1.0.0"):
            with self.assertRaises(ValueError): distribution.version(invalid)

    def test_catalog_rejects_foreign_sources_bad_hash_and_abi(self):
        catalog = distribution.merged_catalog(distribution.empty_catalog(), {"one": record()})
        for key, value in (("url", "https://evil.invalid/trainer.zip"), ("sha256", "bad"), ("size", True), ("moduleABI", 2)):
            invalid = copy.deepcopy(catalog); invalid["modules"][0]["versions"][0][key] = value
            with self.assertRaises(ValueError): distribution.validate_catalog(invalid)

    def test_launcher_confirmation_requires_published_stable_assets(self):
        release = dict(tag_name="v1.2.3", draft=False, prerelease=False,
                       body="<!-- trainerdock-launcher-fingerprint:" + "a" * 64 + " -->",
                       assets=[dict(name=name,size=10,digest="sha256:" + "b" * 64) for name in ("TrainerDock-macOS-arm64.zip","SHA256SUMS")])
        self.assertEqual(distribution.confirmed_launcher(release)["version"], "1.2.3")
        release["prerelease"] = True
        self.assertIsNone(distribution.confirmed_launcher(release))

    def test_package_exact_files_deterministic_and_profiles_unchanged(self):
        build_root = self.root / "Build"
        product = build_root / "Modules/one.mhtmodule"; product.mkdir(parents=True)
        manifest = record()["manifest"]
        (product / "Module.json").write_text(json.dumps(manifest))
        (product / "TrainerConfig.json").write_text(json.dumps(dict(app=dict(version="1.0.0"), profiles=manifest["profiles"])))
        (product / "Trainer.dylib").write_bytes(b"test-only fixture runtime")
        (product / "LICENSE").write_text("fixture license")
        item = dict(id="one",version="1.0.1",fingerprint="a" * 64)
        receipt = build_root / "BuildFingerprints/one.json"; receipt.parent.mkdir()
        receipt.write_text(json.dumps(dict(fingerprint=item["fingerprint"],sha256=hashlib.sha256((product/"Trainer.dylib").read_bytes()).hexdigest())))
        with patch.object(distribution,"ROOT", self.root), patch.object(distribution,"module_fingerprint",return_value=item["fingerprint"]), patch("build.external_build_path", side_effect=Path), patch("xcode_support.verify_products"):
            first = distribution.package_module(build_root,item)
            second = distribution.package_module(build_root,item)
        self.assertEqual(first,second)
        archive = build_root / "Distribution/Trainers/one-1.0.1.zip"
        with zipfile.ZipFile(archive) as reader:
            self.assertEqual(reader.namelist(), ["one.mhtmodule/" + name for name in distribution.FILES])
            packaged = json.loads(reader.read("one.mhtmodule/Module.json"))
            self.assertEqual(packaged["version"],"1.0.1")
            self.assertEqual(packaged["profiles"],manifest["profiles"])
        self.assertEqual(json.loads((product/"Module.json").read_text())["version"],"1.0.0")
        (product / "Trainer.dylib").write_bytes(b"stale or replaced runtime fixture")
        with patch.object(distribution,"ROOT", self.root), patch.object(distribution,"module_fingerprint",return_value=item["fingerprint"]), patch("build.external_build_path", side_effect=Path), patch("xcode_support.verify_products"):
            with self.assertRaises(ValueError): distribution.package_module(build_root,item)

    def test_bootstrap_is_confirmed_catalog_or_empty(self):
        destination = self.root / "app/TrainerCatalog.json"
        with patch.dict("os.environ",{},clear=True):
            distribution.bootstrap(self.root,destination)
        self.assertEqual(distribution.read_catalog(destination), distribution.empty_catalog())

    def test_clean_ci_build_root_has_ownership_before_planning(self):
        build_root = self.root / "CleanBuild"
        distribution.prepare_build_root(build_root)
        self.assertTrue((build_root / ".trainerdock-build").is_file())
        distribution.write_json(build_root / "Distribution/plan.json", {})
        distribution.prepare_build_root(build_root)
        foreign = self.root / "ForeignBuild"; foreign.mkdir(); (foreign / "unrelated").touch()
        with self.assertRaises(ValueError): distribution.prepare_build_root(foreign)

    def test_wrapper_receipt_binds_final_codesigned_bytes(self):
        import build
        build_root = self.root / "FinalBuild"
        distribution.prepare_build_root(build_root)
        product = build_root / "Modules/one.mhtmodule/Trainer.dylib"
        product.parent.mkdir(parents=True)
        product.write_bytes(b"before-final-codesign")
        receipt = build_root / "BuildFingerprints/one.json"
        receipt.parent.mkdir(); receipt.write_text('{"obsolete":true}')
        def xcode(*args, **kwargs):
            self.assertFalse(receipt.exists(), "old receipt survives failed native build")
            product.write_bytes(b"after-xcode-final-codesign")
        def verify(*args, **kwargs):
            self.assertEqual(product.read_bytes(), b"after-xcode-final-codesign")
            self.assertFalse(receipt.exists(), "receipt issued before final signature verification")
        with patch("xcode_project.generate"), patch("xcode_project.released_modules",return_value=[self.root/"Modules/one"]), patch.object(build.subprocess,"check_output",return_value="27.0"), patch.object(build,"run",side_effect=xcode), patch("xcode_support.verify_products",side_effect=verify), patch.object(distribution,"module_fingerprint",return_value="a"*64):
            build.build(build_root,module_id="one",configuration="Release")
        stored = json.loads(receipt.read_text())
        self.assertEqual(stored["sha256"],hashlib.sha256(product.read_bytes()).hexdigest())
        self.assertNotEqual(stored["sha256"],hashlib.sha256(b"before-final-codesign").hexdigest())
        with patch("xcode_project.generate"), patch("xcode_project.released_modules",return_value=[self.root/"Modules/one"]), patch.object(build.subprocess,"check_output",return_value="27.0"), patch.object(build,"run",side_effect=xcode), patch("xcode_support.verify_products",side_effect=verify), patch.object(distribution,"module_fingerprint",side_effect=["a"*64,"b"*64]):
            with self.assertRaises(ValueError): build.build(build_root,module_id="one",configuration="Release")
        self.assertFalse(receipt.exists(), "changed-during-build source received a publication receipt")

    def test_publication_refuses_stale_baseline_before_mutating(self):
        github = distribution.GitHub("test-only", "commit")
        previous = distribution.empty_catalog()
        newer = distribution.merged_catalog(previous,{"one":record()})
        with patch.object(distribution,"fetch_catalog",return_value=newer), patch.object(github,"request") as request:
            with self.assertRaises(ValueError): github.publish_trainers(previous,{},self.root)
            request.assert_not_called()

    def test_catalog_transaction_rolls_back_and_retries(self):
        previous = distribution.empty_catalog()
        updated = distribution.merged_catalog(previous,{"one":record()})
        assets = {1: dict(id=1,name="catalog.json",digest="sha256:"+hashlib.sha256(distribution.json_bytes(previous)).hexdigest(),size=len(distribution.json_bytes(previous)))}
        payloads = {1: previous}
        github = distribution.GitHub("fixture", "commit")
        release = dict(id=1,draft=False,assets=list(assets.values()))
        def request(path, method="GET", payload=None, binary=None):
            if path == "/releases/tags/trainer-catalog":
                return dict(release,assets=[dict(item) for item in assets.values()])
            asset_id = int(path.rsplit("/",1)[1])
            if method == "PATCH":
                assets[asset_id].update(payload); return dict(assets[asset_id])
            if method == "DELETE":
                del assets[asset_id]; return None
            raise AssertionError((path,method))
        def upload(_release,name,data):
            number = max(assets,default=1)+1
            item=dict(id=number,name=name,digest="sha256:"+hashlib.sha256(data).hexdigest(),size=len(data))
            assets[number]=item; payloads[number]=json.loads(data); return dict(item)
        def download(_url):
            item=next(item for item in assets.values() if item["name"]=="catalog.json")
            return payloads[item["id"]]
        with patch.object(github,"release",return_value=release), patch.object(github,"request",side_effect=request), patch.object(github,"upload",side_effect=upload), patch.object(distribution,"get_json",side_effect=ValueError("interrupted confirmation")):
            with self.assertRaises(ValueError): github.publish_catalog(updated)
        self.assertEqual([item["name"] for item in assets.values()],["catalog.json"])
        self.assertEqual(download(None),previous)
        with patch.object(github,"release",side_effect=lambda *args:dict(release,assets=list(assets.values()))), patch.object(github,"request",side_effect=request), patch.object(github,"upload",side_effect=upload), patch.object(distribution,"get_json",side_effect=download):
            github.publish_catalog(updated)
        self.assertEqual(download(None),updated)
        self.assertEqual([item["name"] for item in assets.values()],["catalog.json"])


if __name__ == "__main__":
    unittest.main()

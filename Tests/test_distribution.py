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
from unittest.mock import MagicMock
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
        for item in initial["modules"]:
            records[item["id"]]["contentFingerprint"] = item["contentFingerprint"]
        catalog = distribution.merged_catalog(distribution.empty_catalog(), records)
        catalog["launcher"] = dict(version="1.0.0",fingerprint=initial["launcher"]["fingerprint"], sha256="d"*64, size=10)
        catalog["launcher"]["contentBaseline"] = distribution.launcher_baseline(catalog["launcher"], initial["launcher"]["contentFingerprint"])
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

    def test_build_script_refactoring_never_releases_trainers(self):
        catalog = self.confirmed()
        old_build = distribution.module_fingerprint(self.root / "Modules/one", self.root)
        for name in ("build.py", "xcode_project.py", "xcode_support.py"):
            self.write("script/" + name, "# refactored build orchestration\n")
        self.assertNotEqual(old_build, distribution.module_fingerprint(self.root / "Modules/one", self.root))
        self.assertEqual(self.changed(catalog)["modules"], [])
        self.assertFalse(self.changed(catalog)["launcher"]["changed"])

    def test_new_trainer_is_downloadable_without_launcher_release(self):
        catalog = self.confirmed()
        self.write("Modules/new-game/Sources/Main.m", "// new independent trainer")
        self.write("Modules/new-game/Sources/LICENSE", "license")
        self.write("Modules/new-game/Build.json", json.dumps(dict(sources=["Main.m"])))
        self.write("Modules/new-game/Module.json", json.dumps(dict(id="new-game",name="New game",version="1.0.0")))
        self.write("README.md", "new trainer in list")
        self.write("script/xcode_project.py", "# generator supports another trainer family")
        result = self.changed(catalog)
        self.assertEqual([m["id"] for m in result["modules"]], ["new-game"])
        self.assertFalse(result["launcher"]["changed"])
        merged = distribution.merged_catalog(catalog, {"new-game":record("new-game")})
        self.assertEqual(merged["launcher"], catalog["launcher"])
        self.assertIn("new-game", [m["id"] for m in merged["modules"]])

    def test_launcher_content_migration_preserves_exact_release_and_survives_refactoring(self):
        catalog = self.confirmed()
        catalog["launcher"].pop("contentBaseline")
        plan = self.changed(catalog)
        self.assertTrue(plan["catalogChanged"])
        self.assertFalse(plan["launcher"]["changed"])
        seeded = distribution.seed_launcher_content_baseline(catalog, self.root)
        self.assertEqual(seeded["launcher"]["version"], catalog["launcher"]["version"])
        self.assertEqual(seeded["launcher"]["sha256"], catalog["launcher"]["sha256"])
        confirmed = dict(catalog["launcher"])
        merged = distribution.merge_confirmed_launcher(seeded["launcher"], confirmed)
        self.assertEqual(merged, seeded["launcher"])
        self.write("script/build.py", "# orchestration refactor")
        self.assertFalse(self.changed(seeded)["launcher"]["changed"])
        self.assertFalse(self.changed(seeded)["catalogChanged"])
        self.assertTrue(self.changed(catalog)["launcher"]["changed"], "unproven old build cannot be migrated")
        self.write("App/Main.h", "// real application change")
        self.assertTrue(self.changed(seeded)["launcher"]["changed"])
        bad = copy.deepcopy(seeded);bad["launcher"]["sha256"] = "e"*64
        with self.assertRaises(ValueError):distribution.validate_catalog(bad)
        confirmed["sha256"] = "f"*64
        self.assertNotIn("contentBaseline", distribution.merge_confirmed_launcher(seeded["launcher"], confirmed))

    def test_app_versions_paths_and_test_changes_do_not_publish_app(self):
        catalog = self.confirmed()
        self.write("Config/TrainerDock.xcconfig", "FRAMEWORKS = AppKit\nMARKETING_VERSION = 9.9.9\nCURRENT_PROJECT_VERSION = 99\nSYMROOT = /different/build\n")
        self.write("Tests/NewTest.m", "// test")
        self.write("script/release.py", "# packaging orchestration")
        self.assertFalse(self.changed(catalog)["launcher"]["changed"])
        self.write("ModuleSDK/Protocol.h", "// actual host protocol change")
        self.assertTrue(self.changed(catalog)["launcher"]["changed"])

    def test_effective_launcher_and_broker_options_change_app_content(self):
        import plistlib
        objects = {}
        for name in ("TrainerDock", "TrainerDockEpicBroker"):
            objects[name] = dict(isa="PBXNativeTarget",name=name,buildConfigurationList=name+"-list",buildPhases=[])
            objects[name+"-list"] = dict(buildConfigurations=[name+"-release"])
            objects[name+"-release"] = dict(name="Release",buildSettings={"OTHER_LDFLAGS":["-framework","AppKit"]})
        path = self.root/"TrainerDock.xcodeproj/project.pbxproj";path.parent.mkdir()
        path.write_bytes(plistlib.dumps(dict(objects=objects)))
        before = distribution.launcher_content_fingerprint(self.root)
        objects["unrelated-trainer"] = dict(isa="PBXNativeTarget",name="Trainer-new-game",buildConfigurationList="unrelated-config",buildPhases=[])
        path.write_bytes(plistlib.dumps(dict(objects=objects)))
        self.assertEqual(before, distribution.launcher_content_fingerprint(self.root), "adding a trainer target never changes the shipped host")
        objects["TrainerDockEpicBroker-release"]["buildSettings"]["OTHER_LDFLAGS"].append("-lc++")
        path.write_bytes(plistlib.dumps(dict(objects=objects)))
        self.assertNotEqual(before, distribution.launcher_content_fingerprint(self.root))

    def test_app_version_and_build_paths_do_not_release_trainers(self):
        catalog = self.confirmed()
        self.write("Config/TrainerDock.xcconfig", "FRAMEWORKS = AppKit\nMARKETING_VERSION = 99.0.0\nSYMROOT = /different/build\nWARNING_CFLAGS = -Wall\n")
        self.assertEqual(self.changed(catalog)["modules"], [])
        self.write("Config/TrainerDock.xcconfig", "FRAMEWORKS = AppKit\nOTHER_CFLAGS = -fno-objc-arc\n")
        self.assertEqual(len(self.changed(catalog)["modules"]), 3)

    def test_only_changed_module_and_profiles_are_released(self):
        catalog = self.confirmed()
        self.write("Modules/three/Sources/Main.m", "int actual_effect = 1;")
        self.assertEqual([x["id"] for x in self.changed(catalog)["modules"]], ["three"])
        manifest = json.loads((self.root / "Modules/one/Module.json").read_text())
        manifest["profiles"] = [{"id": "new-build", "enabled": True}]
        self.write("Modules/one/Module.json", json.dumps(manifest))
        self.assertEqual([x["id"] for x in self.changed(catalog)["modules"]], ["one", "three"])

    def test_release_number_alone_is_not_a_content_update(self):
        catalog = self.confirmed()
        manifest = json.loads((self.root / "Modules/one/Module.json").read_text())
        manifest["version"] = "9.0.0"
        self.write("Modules/one/Module.json", json.dumps(manifest))
        self.assertEqual(self.changed(catalog)["modules"], [])

    def test_effective_xcode_flags_are_product_inputs(self):
        import plistlib
        objects = {"target": dict(isa="PBXNativeTarget", name="Trainer-one", buildConfigurationList="list", buildPhases=[]),
                   "list": dict(buildConfigurations=["release"]),
                   "release": dict(name="Release", buildSettings={"OTHER_LDFLAGS": ["-framework", "AppKit"]})}
        path = self.root / "TrainerDock.xcodeproj/project.pbxproj"
        path.parent.mkdir()
        path.write_bytes(plistlib.dumps(dict(objects=objects)))
        before = distribution.module_content_fingerprint(self.root / "Modules/one", self.root)
        objects["release"]["buildSettings"]["OTHER_LDFLAGS"].append("-lc++")
        path.write_bytes(plistlib.dumps(dict(objects=objects)))
        self.assertNotEqual(before, distribution.module_content_fingerprint(self.root / "Modules/one", self.root))
        objects["release"]["buildSettings"]["GCC_PREPROCESSOR_DEFINITIONS"] = ["$(inherited)"]
        objects["release"]["buildSettings"]["ARCHS"] = "arm64"
        path.write_bytes(plistlib.dumps(dict(objects=objects)))
        self.write("Config/TrainerDock.xcconfig", "FRAMEWORKS = AppKit\nARCHS = arm64\nGCC_PREPROCESSOR_DEFINITIONS = EFFECT=1")
        before = distribution.module_content_fingerprint(self.root / "Modules/one", self.root)
        self.write("Config/TrainerDock.xcconfig", "FRAMEWORKS = AppKit\nARCHS = x86_64\nGCC_PREPROCESSOR_DEFINITIONS = EFFECT=1")
        self.assertEqual(before, distribution.module_content_fingerprint(self.root / "Modules/one", self.root), "target overrides an app-only architecture change")
        self.write("Config/TrainerDock.xcconfig", "FRAMEWORKS = AppKit\nARCHS = x86_64\nGCC_PREPROCESSOR_DEFINITIONS = EFFECT=2")
        self.assertNotEqual(before, distribution.module_content_fingerprint(self.root / "Modules/one", self.root), "inherited real compiler options remain product inputs")

    def test_migration_requires_real_old_proof_and_retains_rebuild_history(self):
        catalog = self.confirmed()
        for item in catalog["modules"]:
            item.pop("contentBaseline", None)
            item["versions"][0].pop("contentFingerprint", None)
        seeded = distribution.seed_content_baselines(catalog, self.root)
        new = copy.deepcopy(seeded["modules"][0]["versions"][0])
        new["version"] = new["manifest"]["version"] = "1.0.1"
        new["url"] = distribution.BASE_URL + "trainer-one-v1.0.1/one-1.0.1.zip"
        seeded["modules"][0]["versions"].insert(0, new)
        seeded["modules"][0]["contentBaseline"]["version"] = "1.0.1"
        fixed = distribution.demote_build_only_versions(seeded, ["one"], "c" * 40)
        self.assertEqual(fixed["modules"][0]["versions"][0]["version"], "1.0.0")
        self.assertEqual(fixed["modules"][0]["buildOnlyVersions"][0]["release"], new)
        self.assertEqual(self.changed(fixed)["modules"], [])
        self.write("Modules/one/Sources/Main.m", "int real_update = 1;")
        update = self.changed(fixed)["modules"][0]
        self.assertEqual(update["id"], "one")
        self.assertEqual(update["version"], "1.0.2")
        with self.assertRaises(ValueError):
            distribution.seed_content_baselines(catalog, self.root)
        malformed = copy.deepcopy(fixed)
        malformed["modules"][0]["contentBaseline"]["sha256"] = "f" * 64
        with self.assertRaises(ValueError):
            distribution.validate_catalog(malformed)
        changed = copy.deepcopy(seeded)
        changed["modules"][0]["versions"][0]["manifest"]["profiles"].append({"id": "actual-new-store"})
        with self.assertRaises(ValueError):
            distribution.demote_build_only_versions(changed, ["one"], "c" * 40)

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

    def test_launcher_baseline_migration_publishes_catalog_only(self):
        previous = self.confirmed();previous["launcher"].pop("contentBaseline")
        expected = distribution.seed_launcher_content_baseline(previous, self.root)
        seed = distribution.seed_launcher_content_baseline
        github = distribution.GitHub("fixture", "commit")
        with patch.object(distribution,"fetch_catalog",return_value=previous), patch.object(distribution,"seed_launcher_content_baseline",side_effect=lambda value:seed(value,self.root)), patch.object(github,"request") as request, patch.object(github,"publish_catalog") as publish:
            result = github.publish_trainers(previous, {}, self.root)
        request.assert_not_called()
        publish.assert_called_once_with(expected)
        self.assertEqual(result["modules"], previous["modules"])
        self.assertEqual(result["launcher"]["version"], previous["launcher"]["version"])

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
            if method == "GET":
                return dict(assets[asset_id])
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
        with patch.object(github,"release",return_value=release), patch.object(github,"request",side_effect=request), patch.object(github,"upload",side_effect=upload), patch.object(distribution,"download_catalog_asset",side_effect=ValueError("interrupted confirmation")):
            with self.assertRaises(ValueError): github.publish_catalog(updated)
        self.assertEqual([item["name"] for item in assets.values()],["catalog.json"])
        self.assertEqual(download(None),previous)
        with patch.object(github,"release",side_effect=lambda *args:dict(release,assets=list(assets.values()))), patch.object(github,"request",side_effect=request), patch.object(github,"upload",side_effect=upload), patch.object(distribution,"download_catalog_asset",side_effect=lambda asset,token:payloads[asset["id"]]), patch.object(distribution,"get_json",return_value=previous) as stale_cdn:
            github.publish_catalog(updated)
            stale_cdn.assert_not_called()
        self.assertEqual(download(None),updated)
        self.assertEqual([item["name"] for item in assets.values()],["catalog.json"])

    def test_asset_identity_verifies_bytes_and_scopes_auth_before_redirect(self):
        data=distribution.json_bytes(distribution.empty_catalog())
        asset=dict(id=42,name="catalog.json",size=len(data),digest="sha256:"+hashlib.sha256(data).hexdigest())
        opener=MagicMock(); opener.open.return_value.__enter__.return_value.read.return_value=data
        with patch.object(distribution.urllib.request,"build_opener",return_value=opener):
            self.assertEqual(distribution.download_catalog_asset(asset,"private-fixture-token"),distribution.empty_catalog())
        request=opener.open.call_args.args[0]
        self.assertEqual(request.full_url,distribution.API_URL+"/releases/assets/42")
        self.assertEqual(request.get_header("Accept"),"application/octet-stream")
        self.assertEqual(request.get_header("Authorization"),"Bearer private-fixture-token")
        redirected=distribution.AssetRedirect().redirect_request(request,None,302,"Found",{},"https://release-assets.githubusercontent.com/test")
        self.assertIsNone(redirected.get_header("Authorization"))
        opener.open.return_value.__enter__.return_value.read.return_value=b"stale canonical CDN bytes"
        with patch.object(distribution.urllib.request,"build_opener",return_value=opener):
            with self.assertRaises(ValueError): distribution.download_catalog_asset(asset,"private-fixture-token")


if __name__ == "__main__":
    unittest.main()

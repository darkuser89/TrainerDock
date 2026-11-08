# SPDX-License-Identifier: GPL-3.0-only
"""Check the real Xcode graph: platform minimum, isolation and runnable schemes."""
import json
import importlib.util
from pathlib import Path
import plistlib
import subprocess
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "TrainerDock.xcodeproj"


class XcodeProjectTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.project = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-", str(PROJECT / "project.pbxproj")]))
        cls.objects = cls.project["objects"]
        cls.targets = {p["name"]: p for p in cls.objects.values() if p["isa"] == "PBXNativeTarget"}

    def test_every_released_trainer_has_its_own_native_target(self):
        modules = [p for p in (ROOT / "Modules").glob("*/Build.json")
                   if not json.loads(p.read_text()).get("developmentOnly")]
        self.assertEqual(set(self.targets), {"TrainerDock", "TrainerDockEpicBroker", *["Trainer-" + p.parent.name for p in modules]})
        for name, target in self.targets.items():
            source_phases = [self.objects[p] for p in target["buildPhases"]
                             if self.objects[p]["isa"] == "PBXSourcesBuildPhase"]
            self.assertEqual(len(source_phases), 1)
            sources = [self.objects[self.objects[p]["fileRef"]]["path"] for p in source_phases[0]["files"]]
            self.assertTrue(sources)
            self.assertFalse(any(p.startswith(("Tests/", "Templates/")) for p in sources))
            self.assertTrue(all((ROOT / p).is_file() for p in sources))
            if name == "TrainerDock":
                self.assertEqual(target["productType"], "com.apple.product-type.application")
                self.assertTrue(all(p.startswith(("App/", "Core/", "ModuleSDK/")) for p in sources))
                self.assertNotIn("App/MHTEpicBroker.m", sources)
                self.assertIn("Core/MHTEpicLaunch.m", sources)
            elif name == "TrainerDockEpicBroker":
                self.assertEqual(target["productType"], "com.apple.product-type.tool")
                self.assertEqual(sources, ["App/MHTEpicBroker.m", "Core/MHTEpicLaunch.m"])
            else:
                self.assertEqual(target["productType"], "com.apple.product-type.library.dynamic")
                self.assertTrue(all(p.startswith(("Modules/", "ModuleSDK/")) for p in sources))

    def test_each_trainer_uses_its_explicit_game_architecture(self):
        for name,target in self.targets.items():
            expected="arm64"
            if name.startswith("Trainer-"):
                expected=json.loads((ROOT/"Modules"/name.removeprefix("Trainer-")/"Build.json").read_text()).get("architecture","arm64")
            for uid in self.objects[target["buildConfigurationList"]]["buildConfigurations"]:
                settings=self.objects[uid]["buildSettings"]
                self.assertEqual(settings.get("ARCHS","arm64"),expected)
                if expected=="x86_64":self.assertEqual(settings["ONLY_ACTIVE_ARCH"],"NO")

    def test_launcher_embeds_its_own_signed_broker_dependency(self):
        app = self.targets["TrainerDock"]
        broker = self.targets["TrainerDockEpicBroker"]
        dependencies = [self.objects[self.objects[p]["target"]]["name"] for p in app["dependencies"]]
        self.assertEqual(dependencies, ["TrainerDockEpicBroker"])
        phases = [self.objects[p] for p in app["buildPhases"] if self.objects[p]["isa"] == "PBXCopyFilesBuildPhase"]
        self.assertEqual(len(phases), 1)
        self.assertEqual(phases[0]["dstSubfolderSpec"], "6")
        self.assertEqual(phases[0]["dstPath"], "")
        self.assertEqual(len(phases[0]["files"]), 1)
        embedded = self.objects[phases[0]["files"][0]]
        self.assertEqual(embedded["fileRef"], broker["productReference"])
        self.assertEqual(embedded["settings"]["ATTRIBUTES"], ["CodeSignOnCopy"])
        product = self.objects[broker["productReference"]]
        self.assertEqual(product["path"], "TrainerDockEpicBroker")
        self.assertEqual(product["explicitFileType"], "compiled.mach-o.executable")
        for uid in self.objects[broker["buildConfigurationList"]]["buildConfigurations"]:
            settings = self.objects[uid]["buildSettings"]
            self.assertEqual(settings["MACH_O_TYPE"], "mh_execute")
            self.assertEqual(settings["SKIP_INSTALL"], "YES")

    def test_generator_is_deterministic_without_writing_products(self):
        spec = importlib.util.spec_from_file_location("trainerdock_xcode_project", ROOT / "script/xcode_project.py")
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        first, second = {}, {}
        generator.write_changed = lambda path, data: first.__setitem__(str(path), data)
        generator.generate()
        generator.write_changed = lambda path, data: second.__setitem__(str(path), data)
        generator.generate()
        self.assertEqual(first, second)
        self.assertEqual(first[str(PROJECT / "project.pbxproj")], (PROJECT / "project.pbxproj").read_bytes())

    def test_native_epic_contract_checks_are_invalidated_by_test_changes(self):
        aggregates = [p for p in self.objects.values() if p["isa"] == "PBXAggregateTarget"]
        self.assertEqual({p["name"] for p in aggregates}, {"TrainerDock-Verified", "TrainerDock-Launcher-Verified"})
        for target in aggregates:
            phases = [self.objects[p] for p in target["buildPhases"]]
            self.assertEqual(len(phases), 1)
            inputs = phases[0]["inputPaths"]
            for path in ("Tests/EpicLaunch/MHTEpicLaunchTests.m", "Core/MHTEpicLaunch.m", "Core/MHTEpicLaunch.h"):
                self.assertIn("$(SRCROOT)/" + path, inputs)
            self.assertIn("$(TRAINERDOCK_BUILD_ROOT)/TrainerDock.app/Contents/MacOS/TrainerDockEpicBroker", inputs)

    def test_platform_minimum_and_build_output_are_shared(self):
        config = (ROOT / "Config/TrainerDock.xcconfig").read_text()
        self.assertIn("MACOSX_DEPLOYMENT_TARGET = 27.0", config)
        self.assertIn("SUPPORTED_PLATFORMS = macosx", config)
        self.assertIn("TRAINERDOCK_BUILD_ROOT = $(HOME)/Library/Developer/TrainerDock", config)
        info = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
        self.assertEqual(info["LSMinimumSystemVersion"], "$(MACOSX_DEPLOYMENT_TARGET)")
        for target in self.targets.values():
            for uid in self.objects[target["buildConfigurationList"]]["buildConfigurations"]:
                settings = self.objects[uid]
                self.assertEqual(self.objects[settings["baseConfigurationReference"]]["path"], "Config/TrainerDock.xcconfig")
                self.assertNotIn("MACOSX_DEPLOYMENT_TARGET", settings["buildSettings"])
                self.assertTrue(settings["buildSettings"]["CONFIGURATION_BUILD_DIR"].startswith("$(TRAINERDOCK_BUILD_ROOT)"))

    def test_run_schemes_launch_only_the_launcher(self):
        for name in ("TrainerDock", "TrainerDock-Launcher"):
            scheme = ET.parse(PROJECT / "xcshareddata/xcschemes" / (name + ".xcscheme"))
            runnable = scheme.find("./LaunchAction/BuildableProductRunnable/BuildableReference")
            self.assertEqual(runnable.attrib["BlueprintName"], "TrainerDock")
            self.assertEqual(runnable.attrib["BuildableName"], "TrainerDock.app")
        for scheme in (PROJECT / "xcshareddata/xcschemes").glob("Trainer-*.xcscheme"):
            self.assertIsNone(ET.parse(scheme).find("./LaunchAction/BuildableProductRunnable"))


if __name__ == "__main__":
    unittest.main()

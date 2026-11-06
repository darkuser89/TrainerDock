# SPDX-License-Identifier: GPL-3.0-only
"""Check the real Xcode graph: platform minimum, isolation and runnable schemes."""
import json
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
        self.assertEqual(set(self.targets), {"TrainerDock", *["Trainer-" + p.parent.name for p in modules]})
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
            else:
                self.assertEqual(target["productType"], "com.apple.product-type.library.dynamic")
                self.assertTrue(all(p.startswith(("Modules/", "ModuleSDK/")) for p in sources))

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

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build the explicit Control store test. Does not launch or stop any application."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "script"))
from build import compile_object, link, run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--profile", required=True,
                        choices=("control-steam-arm64", "control-mas-arm64", "control-mas-1-33-1-arm64"))
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if Path("/private/tmp") not in output.parents:
        parser.error("Temporary test output must be below /private/tmp")
    source = ROOT / "Modules/control/Sources"
    sdk = ROOT / "ModuleSDK"
    module = Path.home() / "Library/Developer/TrainerDock/Modules/control.mhtmodule"
    profiles = json.loads((ROOT / "Modules/control/Module.json").read_text())["profiles"]
    profile = dict(next(p for p in profiles if p["id"] == args.profile), enabled=True)
    app = args.app.resolve()
    executable = app / "Contents/MacOS" / profile["executable"]
    if not executable.is_file():
        parser.error("Profile executable is absent")
    # Never replace a loaded product or test library. This tool only writes its
    # own outputs; the supplied app remains completely untouched.
    for library in (module / "Trainer.dylib", output / "MASProbe.dylib"):
        if library.exists() and subprocess.run(
                ["lsof", "-t", str(library)], capture_output=True).stdout.strip():
            parser.error(f"Library is loaded; end the test normally first: {library}")
    output.mkdir(mode=0o700, parents=True, exist_ok=True)
    symbols = ["MHTAcceptCommand", "MHTDecodeMessage", "MHTPost",
               "MHTControlAddress", "MHTControlBuildLabel", "MHTControlEngineIdentity",
               "MHTControlMainImage", "MHTControlOnEngineFrame", "MHTControlRead",
               "MHTControlSchedule", "MHTControlServer", "MHTControlSimulationRate",
               "MHTControlWrite"]
    exports = {line.split()[-1] for line in subprocess.check_output(
        ["nm", "-gU", str(module / "Trainer.dylib")], text=True).splitlines() if line.split()}
    if any("_" + name not in exports for name in symbols):
        parser.error("Product runtime is missing required native test exports")
    compile_object(ROOT / "Tests/Control/MASProbe.mm", output / "MASProbe.o", [source, sdk])
    # Permit only the exact C exports above. A mistaken C++ import now fails
    # here, before a game is started, instead of becoming a null dyld call.
    link([output / "MASProbe.o"], output / "MASProbe.dylib", True,
         ["_" + name for name in symbols])
    run(["codesign", "-s", "-", output / "MASProbe.dylib"])
    compile_object(ROOT / "Tests/Control/StoreHarness.m", output / "StoreHarness.o", [sdk])
    compile_object(sdk / "MHTProtocol.m", output / "MHTProtocol.o", [sdk])
    link([output / "StoreHarness.o", output / "MHTProtocol.o"], output / "StoreHarness")
    (output / "TrainerConfig.json").write_text(json.dumps({
        "schemaVersion": 1, "app": {"name": "TrainerDock Control test", "bundleIdentifier":
        "local.mht.test", "version": "1", "build": "1"}, "profiles": [profile]}))
    environment = {"DYLD_INSERT_LIBRARIES": str(module / "Trainer.dylib") + ":" +
                   str(output / "MASProbe.dylib"), "MHT_CONFIG": str(output / "TrainerConfig.json"),
                   "MHT_PROFILE": args.profile, "MHT_TARGET": str(executable),
                   "MHT_MODULE": "control", "MHT_SESSION": str(uuid.uuid4()),
                   "MHT_OPTIONS": json.dumps({"glassIntensity": .5})}
    environment.update(profile.get("launchEnvironment", {}))
    (output / "Launch.json").write_text(json.dumps({"app": str(app), "environment": environment}))
    (output / "Requests.json").write_text(json.dumps({"serial": 0, "commands": []}))
    print("Built and linked store test; no application started.")


if __name__ == "__main__":
    main()

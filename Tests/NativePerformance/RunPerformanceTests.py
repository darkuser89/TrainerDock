#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Run counted native adapter fixtures. Never launch/close games or replace products."""
import argparse
import json
import os
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "script"))
import build


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, default=Path.home() / "Library/Developer/TrainerDock")
    parser.add_argument("--configuration", choices=("Debug", "Release"), default="Debug")
    parser.add_argument("--modules", nargs="*", help="Only suites affected by these module IDs; omitted means all.")
    args = parser.parse_args()
    selected = None if args.modules is None else set(args.modules)
    if selected == set():
        print("No changed native trainer selected; no performance fixtures required.")
        return
    build_dir = build.external_build_path(args.build_dir)
    if not (build_dir / ".trainerdock-build").is_file():
        parser.error("Existing TrainerDock build required; this runner never creates a product build.")
    suites = (
        ("control", ("NativeAdapter.mm", "ControlInventory.mm", "ControlInput.mm"),
         ("Tests/Control/IdleMaintenanceTests.mm", "Tests/Control/InventoryMaintenanceTests.mm")),
        ("no-mans-sky", ("NMSAdapter.m",), ("Tests/NoMansSky/IdleMaintenanceTests.m",)),
        ("resident-evil-2", ("RE2Adapter.m", "RE3Adapter.m", "RE4Adapter.m", "RE7Adapter.m", "RE8Adapter.m"),
         ("Tests/ResidentEvil/IdleMaintenanceTests.m", "Tests/ResidentEvil/LedgerPerformanceTests.m")),
    )
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(("MHT_", "RE2_", "NMS_"))}
    with tempfile.TemporaryDirectory(prefix="trainerdock-native-perf-", dir="/private/tmp") as temporary:
        output = Path(temporary)
        for module_id, changed, tests in suites:
            if module_id == "resident-evil-2" and selected is not None:
                candidates=sorted(m for m in selected if m in {"resident-evil-2","resident-evil-3","resident-evil-4","resident-evil-7","resident-evil-village"})
                if not candidates:continue
                module_id=candidates[0]
            elif selected is not None and module_id not in selected:
                continue
            module = ROOT / "Modules" / module_id
            config = json.loads((module / "Build.json").read_text())
            source = (module / config.get("sourceRoot", "Sources")).resolve()
            object_dir = build_dir / "Xcode/Build/Intermediates.noindex/TrainerDock.build" / args.configuration / ("Trainer-" + module_id + ".build/Objects-normal/arm64")
            objects = {}
            for name in (*config["sources"], *config.get("sdkSources", ()), "MHTProtocol.m"):
                if name == "Runtime.m":
                    continue
                path = object_dir / (Path(name).stem + ".o")
                if not path.is_file():
                    parser.error(f"Build object absent (run the regular build first): {path}")
                objects[name] = path
            includes = [source, ROOT / "ModuleSDK"]
            for name in changed:
                obj = output / (module_id + "-" + name + ".o")
                build.compile_object(source / name, obj, includes, config.get("defines", ()))
                objects[name] = obj
            for test in tests:
                obj = output / (module_id + "-test.o")
                executable = output / (module_id + "-test")
                build.compile_object(ROOT / test, obj, includes, config.get("defines", ()))
                build.link([obj, *objects.values()], executable)
                build.run([executable], env=environment)
        if selected is None or selected.intersection({"turok","turok-2"}):
            fog_obj = output / "fog-performance.o"
            build.compile_object(ROOT / "Tests/Kex/FogPerformanceTests.m", fog_obj,
                                 [ROOT / "Modules/_Shared/Kex"])
            fog_test = output / "fog-performance"
            build.link([fog_obj], fog_test)
            build.run([fog_test], env=environment)
    print("PASS: selected native performance fixtures; temporary objects removed. No game started." if selected is not None else
          "PASS: all native performance fixtures; temporary objects removed. No game started.")


if __name__ == "__main__":
    main()

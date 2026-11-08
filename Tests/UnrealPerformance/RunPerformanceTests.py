#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Synthetic engine performance contracts; never loads or starts a game.

CI supplies a standalone Lua/LuaJIT library explicitly. All native fixtures and
temporary objects stay outside source/audit and are removed after this run.
"""
import argparse
import os
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "script"))
import build

parser = argparse.ArgumentParser()
parser.add_argument("--lua-library", default=os.environ.get("TRAINERDOCK_TEST_LUA_LIBRARY"),
                    help="Explicit standalone Lua/LuaJIT library for inZOI's synthetic fixture.")
parser.add_argument("--build-dir", default=str(Path.home() / "Library/Developer/TrainerDock"))
parser.add_argument("--modules", nargs="*", help="Only these changed modules; omitted means all.")
args = parser.parse_args()
selected=None if args.modules is None else set(args.modules)
if selected is not None and not selected.intersection({"frostpunk-2","inzoi","stray"}):
    print("No changed Unreal trainer selected; no performance fixtures required.")
    raise SystemExit(0)
needs_lua=selected is None or "inzoi" in selected
if needs_lua and not args.lua_library:
    parser.error("--lua-library or TRAINERDOCK_TEST_LUA_LIBRARY is required; no game runtime is selected automatically")
library = Path(args.lua_library).expanduser().resolve() if needs_lua else None
if needs_lua and not library.is_file():
    parser.error("Explicit Lua test library does not exist")
out = build.external_build_path(args.build_dir)
out.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="engine-performance-", dir=out) as raw:
    temp = Path(raw)
    objects = {}

    def object_for(relative, includes):
        path = ROOT / relative
        if relative not in objects:
            target = temp / ("object-" + str(len(objects)) + ".o")
            build.compile_object(path, target, includes)
            objects[relative] = target
        return objects[relative]

    cases = [
        ("Frostpunk2", "frostpunk-2", "SpeedContractTests", ["Speed.mm"]),
        ("Frostpunk2", "frostpunk-2", "ReflectionCacheTests", []),
        ("InZOI", "inzoi", "VMDispatchTests", []),
        ("Stray", "stray", "InputLeaseTests", []),
        ("Stray", "stray", "PlayerLeaseTests", ["PlayerEffects.mm"]),
        ("Stray", "stray", "DefluxorContractTests", ["Defluxor.mm"]),
        ("Stray", "stray", "EnemyContractTests", ["EnemyEffects.mm"]),
        ("Stray", "stray", "MetadataCacheTests", []),
        ("Stray", "stray", "FieldSearchTests", []),
    ]
    for family, module, name, sources in cases:
        if selected is not None and module not in selected:continue
        includes = [ROOT / "Modules" / module / "Sources", ROOT / "ModuleSDK"]
        linked = [object_for(f"Tests/{family}/{name}.mm", includes)]
        if name == "VMDispatchTests":
            linked.append(object_for("Tests/InZOI/VMDispatchSymbols.mm", includes))
        linked += [object_for(f"Modules/{module}/Sources/{source}", includes) for source in sources]
        executable = temp / (family + "-" + name)
        build.link(linked, executable)
        build.run([executable])
        print(f"PASS: {family}/{name} (synthetic only)", flush=True)

    if needs_lua:build.run([sys.executable, "-B", ROOT / "Tests/InZOI/IdleTickTests.py", library])
print("PASS: selected engine performance contracts. No game started; temporary native products removed." if selected is not None else
      "PASS: engine performance contracts. No game started; temporary native products removed.", flush=True)

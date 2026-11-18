#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build private, read-only x86_64 diagnostics; never start or stop any game."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BUILD_ROOT = Path.home() / "Library/Developer/TrainerDock"


def run(arguments):
    subprocess.run([str(item) for item in arguments], check=True)


def protect_loaded(path):
    if not path.exists():
        return
    lsof = shutil.which("lsof") or "/usr/sbin/lsof"
    result = subprocess.run([lsof, "-t", str(path)], capture_output=True, text=True, timeout=15)
    if result.stdout.strip():
        raise SystemExit("Geladene Frostpunk-Prüfbibliothek bleibt unverändert; erst regulär beenden.")
    if result.returncode not in (0, 1):
        raise SystemExit("Verwendung der vorhandenen Prüfbibliothek kann nicht sicher geprüft werden.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, default=DEFAULT_BUILD_ROOT)
    parser.add_argument("--stage", action="store_true", help="Bereitet nur den kurzlebigen Austauschbestand vor.")
    args = parser.parse_args()
    build_root = args.build_dir.expanduser().resolve()
    if build_root == ROOT or ROOT in build_root.parents:
        raise SystemExit("Prüfbinaries gehören außerhalb des Codeordners.")
    if "audit" in str(build_root).lower():
        raise SystemExit("Prüfbinaries gehören nicht in eine Auditablage.")
    out = build_root / "Tests/Frostpunk"
    if args.stage:
        out = out / "Exchange"
    out.mkdir(parents=True, exist_ok=True)
    destination = out / "IngameProbe.dylib"
    protect_loaded(destination)
    # Keep one current test build. The exchange directory is deleted on success or failure.
    with tempfile.TemporaryDirectory(prefix=".probe-candidate-", dir=out) as temporary:
        candidate = Path(temporary)
        request_tests = candidate / "ProbeRequestTests"
        run(["xcrun", "clang", "-arch", "x86_64", "-mmacosx-version-min=27.0",
             "-fobjc-arc", "-fblocks", "-Wall", "-Wextra", "-Werror", "-framework", "Foundation",
             ROOT / "Tests/Frostpunk/ProbeRequestTests.m", "-Wl,-export_dynamic", "-o", request_tests])
        run([request_tests])
        library = candidate / destination.name
        run(["xcrun", "clang", "-dynamiclib", "-arch", "x86_64", "-mmacosx-version-min=27.0",
             "-fobjc-arc", "-fblocks", "-fvisibility=hidden", "-Wall", "-Wextra", "-Werror",
             "-framework", "Foundation", ROOT / "Tests/Frostpunk/IngameProbe.m",
             "-Wl,-install_name,@rpath/IngameProbe.dylib", "-o", library])
        run(["codesign", "--force", "--sign", "-", "--timestamp=none", library])
        run(["codesign", "--verify", "--strict", library])
        architectures = subprocess.check_output(["lipo", "-archs", str(library)], text=True).strip()
        if architectures != "x86_64":
            raise SystemExit("Prüfbibliothek besitzt nicht ausschließlich die Originalarchitektur x86_64.")
        query = candidate / "Query"
        run(["xcrun", "swiftc", "-target", "x86_64-apple-macos27.0",
             "-module-cache-path", out / "SwiftCache", ROOT / "Tests/Frostpunk/Query.swift", "-o", query])
        run(["codesign", "--force", "--sign", "-", "--timestamp=none", query])
        run(["codesign", "--verify", "--strict", query])
        protect_loaded(destination)
        os.replace(library, destination)
        os.replace(query, out / "Query")
        os.replace(request_tests, out / "ProbeRequestTests")
    print("Reinlesende Frostpunk-Prüfer gebaut und ad-hoc versiegelt; kein Spiel gestartet.")
    print(destination)
    print(out / "Query")


if __name__ == "__main__":
    main()

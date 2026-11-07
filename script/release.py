#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Package verified external products; never includes game files or build caches."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

from build import ROOT, external_build_path
from xcode_project import released_modules
from xcode_support import verify_products


def package(root):
    root = external_build_path(root)
    verify_products(root)
    app = root / "TrainerDock.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    destination = root / "Distribution"
    destination.mkdir(exist_ok=True)
    archive = destination / "TrainerDock-macOS-arm64.zip"
    with tempfile.TemporaryDirectory(prefix="release-", dir=root) as temporary:
        payload = Path(temporary) / "TrainerDock"
        payload.mkdir()
        shutil.copytree(app, payload / app.name, symlinks=True)
        modules = payload / "Modules"
        modules.mkdir()
        inventory = []
        for source in released_modules():
            name = source.name + ".mhtmodule"
            target = modules / name
            target.mkdir()
            for filename in ("Module.json", "TrainerConfig.json", "Trainer.dylib", "LICENSE"):
                shutil.copy2(root / "Modules" / name / filename, target / filename)
            manifest = json.loads((target / "Module.json").read_text())
            inventory.append({"id": manifest["id"], "version": manifest["version"],
                              "sha256": hashlib.sha256((target / "Trainer.dylib").read_bytes()).hexdigest()})
        shutil.copy2(ROOT / "LICENSE", payload / "LICENSE")
        (payload / "README.txt").write_text(
            "TrainerDock – Apple Silicon, macOS 27+\n\n"
            "Den gesamten TrainerDock-Ordner behalten: TrainerDock.app und Modules gehören zusammen.\n"
            "TrainerDock.app öffnen und die installierten Spiele in den Pfadeinstellungen auswählen.\n"
            "Die App ist ad-hoc signiert, nicht Developer-ID-signiert oder notarisiert.\n"
            "Quellcode und Lizenz: https://github.com/darkuser89/TrainerDock\n")
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        (payload / "BUILD.json").write_text(json.dumps({"version": info["CFBundleShortVersionString"],
            "build": info["CFBundleVersion"], "commit": commit, "minimumMacOS": "27.0",
            "architecture": "arm64", "modules": inventory}, indent=2) + "\n")
        temporary_zip = Path(temporary) / archive.name
        subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(payload), str(temporary_zip)], check=True)
        temporary_zip.replace(archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (destination / "SHA256SUMS").write_text(digest + "  " + archive.name + "\n")
    print(f"Verified release package: {archive} ({len(inventory)} trainers)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, default=Path.home() / "Library/Developer/TrainerDock")
    package(parser.parse_args().build_dir)

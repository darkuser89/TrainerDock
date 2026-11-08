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
from xcode_support import verify_products


def package(root):
    root = external_build_path(root)
    verify_products(root, modules=False)
    app = root / "TrainerDock.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    destination = root / "Distribution"
    destination.mkdir(exist_ok=True)
    archive = destination / "TrainerDock-macOS-arm64.zip"
    with tempfile.TemporaryDirectory(prefix="release-", dir=root) as temporary:
        payload = Path(temporary) / "TrainerDock.app"
        shutil.copytree(app, payload, symlinks=True)
        modules = payload / "Contents/Resources/Modules"
        if any(path.suffix in (".mhtmodule", ".dylib") for path in modules.iterdir()):
            raise ValueError("Launcherpakete enthalten keine Trainerbibliotheken.")
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        (payload / "Contents/Resources/BUILD.json").write_text(json.dumps({"version": info["CFBundleShortVersionString"],
            "build": info["CFBundleVersion"], "commit": commit, "minimumMacOS": "27.0",
            "architecture": "arm64", "modules": [], "moduleABI": 1,
            "distribution": "downloaded-trainers"}, indent=2) + "\n")
        subprocess.run(["codesign","--force","--sign","-","--timestamp=none",str(payload)],check=True)
        subprocess.run(["codesign","--verify","--deep","--strict",str(payload)],check=True)
        subprocess.run([str(payload/"Contents/MacOS/TrainerDock"),"--check"],check=True)
        temporary_zip = Path(temporary) / archive.name
        subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(payload), str(temporary_zip)], check=True)
        temporary_zip.replace(archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (destination / "SHA256SUMS").write_text(digest + "  " + archive.name + "\n")
    (destination / "RELEASE_NOTES.md").write_text(
        "Apple Silicon · macOS 27 oder neuer.\n\n"
        "Trainer einzeln in der App herunterladen und installierte Versionen verwalten. "
        "Updates über TrainerDock → Nach Updates suchen.\n\n"
        "Ohne Developer-ID-Signierung oder Notarisierung; "
        "keine zusätzlichen Signierschlüssel erforderlich.\n")
    (destination / "launcher-record.json").write_text(json.dumps({
        "version": info["CFBundleShortVersionString"], "sha256": digest,
        "size": archive.stat().st_size}, indent=2) + "\n")
    print(f"Verified launcher-only release package: {archive}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, default=Path.home() / "Library/Developer/TrainerDock")
    package(parser.parse_args().build_dir)

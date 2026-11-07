#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Create only our own managed CI dependencies from verified local originals."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

from build import ROOT, external_build_path
from managed import compile_managed, managed_source_hash
from xcode_project import released_modules


def prepare(build_dir, release):
    if not re.fullmatch(r"managed-inputs-v[0-9]+", release):
        raise ValueError("Baustein-Release muss managed-inputs-vNUMMER heißen.")
    if os.environ.get("TRAINERDOCK_MANAGED_IMAGES"):
        raise ValueError("Zum Neukompilieren TRAINERDOCK_MANAGED_IMAGES entfernen; Originalreferenzen erforderlich.")
    destination = external_build_path(build_dir) / "ManagedInputs"
    destination.mkdir(parents=True, exist_ok=True)
    lock = {"schemaVersion": 1, "release": release, "modules": {}}
    with tempfile.TemporaryDirectory(prefix="compile-", dir=destination) as temporary:
        staging = Path(temporary)
        for module in released_modules():
            config = json.loads((module / "Build.json").read_text())
            if not config.get("managed"):
                continue
            manifest = json.loads((module / "Module.json").read_text())
            folder = staging / module.name
            folder.mkdir()
            compile_managed(module, manifest, config, folder)
            filename = module.name + ".Managed.dll"
            data = (folder / filename).read_bytes()
            lock["modules"][module.name] = {"file": filename, "sha256": hashlib.sha256(data).hexdigest(),
                "sourceSha256": managed_source_hash(module, manifest, config)}
        for name, entry in lock["modules"].items():
            (staging / name / entry["file"]).replace(destination / entry["file"])
    (ROOT / "Config/ManagedImages.json").write_text(json.dumps(lock, indent=2) + "\n")
    print(f"Own managed CI inputs: {destination}; publish as {release}. No game files copied.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, default=Path.home() / "Library/Developer/TrainerDock")
    parser.add_argument("--release", required=True)
    args = parser.parse_args()
    prepare(args.build_dir, args.release)

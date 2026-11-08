#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Xcode build phases: package real native products and run isolated checks.

The application and Trainer.dylib are compiled/linked/signed by native Xcode
targets. These phases reuse their objects; they never compile a second product.
Test executables exist only in a temporary external directory, never in the app.
"""
import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import shutil

import build
from managed import compile_managed
from xcode_project import released_modules

ROOT = Path(__file__).resolve().parent.parent


def environment_path(name):
    return Path(os.environ[name]).expanduser().resolve()


def build_root():
    root = build.external_build_path(os.environ.get("TRAINERDOCK_BUILD_ROOT", str(Path.home() / "Library/Developer/TrainerDock")))
    root.mkdir(parents=True, exist_ok=True)
    marker = root / ".trainerdock-build"
    if not marker.exists() and any(root.iterdir()):
        # Xcode creates intermediates before a phase can establish ownership.
        if any(p.name not in ("Xcode", "Modules", "TrainerDock.app") for p in root.iterdir()):
            raise ValueError("Fremden nichtleeren Buildordner nicht übernehmen.")
    marker.touch()
    return root


def module_data(module_id):
    modules = {p.name: p for p in released_modules()}
    if module_id not in modules:
        raise ValueError("Unbekanntes oder nicht freigegebenes Trainermodul.")
    module = modules[module_id]
    return module, json.loads((module / "Module.json").read_text()), json.loads((module / "Build.json").read_text())


def object_file(folder, filename):
    path = folder / (Path(filename).stem + ".o")
    if not path.is_file():
        raise ValueError(f"Xcode-Objekt fehlt: {path}")
    return path


def stamp():
    (environment_path("TARGET_TEMP_DIR") / "verified.stamp").touch()


def icon():
    # Keep only the approved source artwork in code; generated sizes stay external.
    source = ROOT / "App/Resources/TrainerDock.png"
    destination = environment_path("TARGET_BUILD_DIR") / os.environ["UNLOCALIZED_RESOURCES_FOLDER_PATH"] / "TrainerDock.icns"
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="icon-", dir=environment_path("TARGET_TEMP_DIR")) as temp:
        iconset = Path(temp) / "TrainerDock.iconset"
        iconset.mkdir()
        for points in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                pixels = points * scale
                suffix = "@2x" if scale == 2 else ""
                output = iconset / f"icon_{points}x{points}{suffix}.png"
                build.run(["/usr/bin/sips", "-z", str(pixels), str(pixels), source, "--out", output], stdout=subprocess.DEVNULL)
        build.run(["/usr/bin/iconutil", "-c", "icns", iconset, "-o", destination])


def managed(module_id):
    build_root()
    module, manifest, config = module_data(module_id)
    folder = environment_path("DERIVED_FILE_DIR")
    folder.mkdir(parents=True, exist_ok=True)
    # Keep a stable header timestamp when compilation produces identical bytes.
    header = folder / config["managed"]["header"]
    with tempfile.TemporaryDirectory(prefix="managed-", dir=folder) as temp:
        stage = Path(temp)
        compile_managed(module, manifest, config, stage)
        data = (stage / header.name).read_bytes()
        if not header.is_file() or header.read_bytes() != data:
            header.write_bytes(data)


def bundle_modules(root):
    app = root / "TrainerDock.app"
    if not app.is_dir():
        return
    target = app / "Contents/Resources/Modules"
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)
    for source in released_modules():
        package = root / "Modules" / (source.name + ".mhtmodule")
        shutil.copytree(package, target / package.name)
    build.run(["codesign", "--force", "--sign", "-", "--timestamp=none", app], stdout=subprocess.DEVNULL)


def package_module(module_id):
    root = build_root()
    _, _, config = module_data(module_id)
    folder = environment_path("OBJECT_FILE_DIR_normal") / config.get("architecture", "arm64")
    names = config["sources"] + config.get("sdkSources", [])
    objects = {name: object_file(folder, name) for name in names}
    common = object_file(folder, "MHTProtocol.m")
    with tempfile.TemporaryDirectory(prefix="checks-", dir=environment_path("TARGET_TEMP_DIR")) as temp:
        build.trainer(ROOT / "Modules" / module_id, root / "Modules", Path(temp), common, native_objects=objects)
    stamp()


def check_launcher():
    root = build_root()
    bundle_modules(root)
    build.run(["/usr/bin/python3", "-B", ROOT / "Tests/test_xcode_project.py"])
    folder = environment_path("PROJECT_TEMP_DIR") / os.environ["CONFIGURATION"] / "TrainerDock.build/Objects-normal/arm64"
    common = object_file(folder, "MHTProtocol.m")
    core = [object_file(folder, p.name) for p in sorted((ROOT / "Core").glob("*.m"))]
    app = [object_file(folder, p.name) for p in sorted((ROOT / "App").glob("*.m"))
           if p.name not in ("main.m", "MHTEpicBroker.m")]
    includes = [ROOT / p for p in ("App", "Core", "ModuleSDK")] + [Path(os.environ.get("TRAINERDOCK_ARCHIVE_INCLUDE", "/opt/homebrew/opt/libarchive/include"))]
    with tempfile.TemporaryDirectory(prefix="checks-", dir=environment_path("TARGET_TEMP_DIR")) as temp:
        stage = Path(temp)
        # This test imports the exact product implementation to exercise private
        # transaction helpers. Do not link the separate Core object a second time.
        epic_obj = stage / "MHTEpicLaunchTests.o"
        build.compile_object(ROOT / "Tests/EpicLaunch/MHTEpicLaunchTests.m", epic_obj, includes)
        epic_test = stage / "MHTEpicLaunchTests"
        build.link([epic_obj], epic_test)
        build.run([epic_test, root / "TrainerDock.app/Contents/MacOS/TrainerDockEpicBroker"])
        for name in ("GameIdentityTests", "MHTTests"):
            obj = stage / (name + ".o")
            build.compile_object(ROOT / "Tests" / (name + ".m"), obj, includes)
            exe = stage / name
            build.link([obj, common, *core], exe)
            build.run([exe, root / "Modules"] if name == "MHTTests" else [exe])
        contents = stage / "LauncherLayoutTests.app/Contents"
        (contents / "MacOS").mkdir(parents=True)
        (contents / "Info.plist").write_bytes(plistlib.dumps(dict(
            CFBundleIdentifier="local.mht.layout-tests", CFBundleExecutable="LayoutTests",
            CFBundlePackageType="APPL", LSMinimumSystemVersion="27.0")))
        # ModuleDirectory resolves next to the test .app, just as it does in production.
        (stage / "Modules").symlink_to(root / "Modules", target_is_directory=True)
        obj = stage / "LauncherLayoutTests.o"
        build.compile_object(ROOT / "Tests/LauncherLayoutTests.m", obj, includes)
        exe = contents / "MacOS/LayoutTests"
        extra = ["-larchive.2"]
        build.link([obj, common, *core, *app], exe, extra_flags=extra)
        build.run([exe])
        update_obj=stage/"UpdaterTests.o"
        build.compile_object(ROOT/"Tests/UpdaterTests.m",update_obj,includes)
        update_contents=stage/"UpdaterTests.app/Contents"
        (update_contents/"MacOS").mkdir(parents=True)
        update_info=plistlib.loads((root/"TrainerDock.app/Contents/Info.plist").read_bytes())
        update_info.update(CFBundleIdentifier="local.trainerdock.updater-tests",CFBundleExecutable="UpdaterTests")
        (update_contents/"Info.plist").write_bytes(plistlib.dumps(update_info))
        update_test=update_contents/"MacOS/UpdaterTests"
        build.link([update_obj,object_file(folder,"MHTUpdater.m"),object_file(folder,"MHTUpdatePackage.m")],update_test,extra_flags=extra)
        build.run([update_test])
    verify_products(root)
    stamp()


def verify_products(root, module_id=None):
    paths = [root / "Modules" / (p.name + ".mhtmodule") for p in released_modules()
             if module_id is None or p.name == module_id]
    for module in paths:
        binary = module / "Trainer.dylib"
        build.run(["codesign", "--verify", "--strict", binary])
        verify_minimum(binary)
        source=ROOT/"Modules"/module.name.removesuffix(".mhtmodule")
        config=json.loads((source/"Build.json").read_text());expected=config.get("architecture","arm64")
        if subprocess.check_output(["xcrun","lipo","-archs",binary],text=True).strip()!=expected:
            raise ValueError(f"Trainerarchitektur passt nicht zum Modulvertrag: {binary}")
        manifest=json.loads((module/"Module.json").read_text())
        if any(profile.get("architecture","arm64")!=expected for profile in manifest["profiles"]):
            raise ValueError(f"Profilarchitektur passt nicht zur Trainerbibliothek: {module}")
    if module_id is None:
        app = root / "TrainerDock.app"
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        if info.get("LSMinimumSystemVersion") != "27.0":
            raise ValueError("Launcher muss macOS 27.0 voraussetzen.")
        if info.get("CFBundleIconFile") != "TrainerDock" or not (app / "Contents/Resources/TrainerDock.icns").is_file():
            raise ValueError("Das TrainerDock-App-Icon fehlt.")
        build.run(["codesign", "--verify", "--deep", "--strict", app])
        verify_minimum(app / "Contents/MacOS/TrainerDock")
        broker = app / "Contents/MacOS/TrainerDockEpicBroker"
        if not broker.is_file() or not os.access(broker, os.X_OK):
            raise ValueError("Der native Epic-Starthelfer fehlt.")
        build.run(["codesign", "--verify", "--strict", broker])
        verify_minimum(broker)
        if subprocess.check_output(["xcrun", "lipo", "-archs", str(broker)], text=True).strip() != "arm64":
            raise ValueError("Der Epic-Starthelfer muss ausschließlich arm64 enthalten.")
        build.run([app / "Contents/MacOS/TrainerDock", "--check"])


def verify_minimum(binary):
    output = subprocess.check_output(["xcrun", "vtool", "-show-build", str(binary)], text=True)
    minimum = [line.split()[1] for line in output.splitlines() if line.strip().startswith("minos ")]
    if minimum != ["27.0"]:
        raise ValueError(f"Unerwartetes Deploymentziel {minimum}: {binary}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("managed", "module", "launcher", "icon"))
    parser.add_argument("module_id", nargs="?")
    args = parser.parse_args()
    if args.action not in ("launcher", "icon") and not args.module_id:
        parser.error("module_id erforderlich")
    {"managed": managed, "module": package_module, "launcher": lambda _: check_launcher(), "icon": lambda _: icon()}[args.action](args.module_id)

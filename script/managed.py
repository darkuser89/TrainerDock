# SPDX-License-Identifier: GPL-3.0-only
"""Compile a module's own C# into an embedded image; never copy game assemblies."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

MANAGED_LOCK = Path(__file__).resolve().parent.parent / "Config/ManagedImages.json"

def managed_source_hash(module, manifest, config):
    """Bind an own compiled image to its exact sources and original ABI profile."""
    settings = config["managed"]
    profile = next(p for p in manifest["profiles"] if p["id"] == settings["referenceProfile"])
    digest = hashlib.sha256(json.dumps({"managed": settings, "profile": profile},
                                     sort_keys=True, separators=(",", ":")).encode())
    for name in settings["sources"]:
        digest.update(name.encode() + b"\0" + (module / name).read_bytes() + b"\0")
    return digest.hexdigest()


def verified_managed_image(directory, module, manifest, config):
    lock = json.loads(MANAGED_LOCK.read_text())
    if lock.get("schemaVersion") != 1:
        raise ValueError("Unbekanntes Managed-Bausteinformat.")
    entry = lock["modules"][manifest["id"]]
    if entry["sourceSha256"] != managed_source_hash(module, manifest, config):
        raise ValueError("Eigene Managed-Quellen/Originalbindung geändert; CI-Baustein lokal neu erzeugen.")
    filename = entry["file"]
    if Path(filename).name != filename or not filename.endswith(".Managed.dll"):
        raise ValueError("Ungültiger eigener Managed-Bausteinpfad.")
    data = (Path(directory) / filename).read_bytes()
    if not 0 < len(data) <= 1024 * 1024 or hashlib.sha256(data).hexdigest() != entry["sha256"]:
        raise ValueError("Eigener Managed-Baustein stimmt nicht mit dem geprüften Hash überein.")
    return data


def compile_managed(module, manifest, config, stage):
    settings = config.get("managed")
    if not settings:
        return
    images = os.environ.get("TRAINERDOCK_MANAGED_IMAGES")
    if images:
        data = verified_managed_image(images, module, manifest, config)
        write_header(stage / settings["header"], data)
        run_policy_tests(module, manifest, settings, stage)
        return
    profile_id = settings["referenceProfile"]
    profile = next(p for p in manifest["profiles"] if p["id"] == profile_id)
    bundle = os.environ.get("TRAINERDOCK_REFERENCE_BUNDLE", os.environ.get("MHT_REFERENCE_BUNDLE", ""))
    if not bundle:
        for domain in ("local.trainerdock.launcher", "local.mht.launcher"):
            result = subprocess.run(["defaults", "read", domain,
                                     f"MHT.{manifest['id']}.path.{profile_id}"],
                                    capture_output=True, text=True)
            bundle = result.stdout.strip() if result.returncode == 0 else ""
            if bundle:
                break
    if not bundle:
        raise ValueError("Managed-Referenzen fehlen: Spielpfad in TrainerDock wählen oder TRAINERDOCK_REFERENCE_BUNDLE setzen.")
    bundle = Path(bundle).resolve()
    for check in profile.get("fileChecks", []):
        relative = Path(check["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Ungültiger Referenzpfad.")
        path = bundle / relative
        if path.stat().st_size != check["fileSize"]:
            raise ValueError(f"Abweichende Originalreferenz: {relative}")
        with path.open("rb") as stream:
            stream.seek(check["offset"])
            digest = hashlib.sha256(stream.read(check["length"])).hexdigest()
        if digest != check["sha256"]:
            raise ValueError(f"Abweichende Originalreferenz: {relative}")
    compiler = managed_compiler()
    refs = bundle / settings["referenceDirectory"]
    output = stage / (manifest["id"] + ".Managed.dll")
    args = ["dotnet", str(compiler), "-noconfig", "-nostdlib+", "-target:library",
            "-deterministic+", "-optimize+", "-warnaserror+", "-langversion:9",
            "-out:" + str(output)]
    args += ["-r:" + str(p) for p in sorted(refs.glob("*.dll"))]
    args += [str(module / p) for p in settings["sources"]]
    if subprocess.run(args).returncode:
        raise ValueError("Eigener Managed-Trainer konnte nicht kompiliert werden.")
    write_header(stage / settings["header"], output.read_bytes())
    run_policy_tests(module, manifest, settings, stage)


def managed_compiler():
    sdks = subprocess.check_output(["dotnet", "--list-sdks"], text=True).splitlines()
    if not sdks:
        raise ValueError("Lokales .NET SDK für C#-Trainer erforderlich.")
    sdk = sdks[-1]
    return Path(sdk.split("[", 1)[1].rstrip("]")) / sdk.split()[0] / "Roslyn/bincore/csc.dll"


def write_header(header, data):
    header.write_text("// Generated in external build stage from this module's own C# only.\n"
                      "static const unsigned char MHTManagedImage[]={\n" +
                      ",\n".join(",".join(str(b) for b in data[i:i+32]) for i in range(0, len(data), 32)) +
                      "\n};\n")


def run_policy_tests(module, manifest, settings, stage):
    if settings.get("policyTests"):
        compiler = managed_compiler()
        root = Path(__file__).resolve().parent.parent
        packs = compiler.parents[4] / "packs/Microsoft.NETCore.App.Ref"
        versions = sorted(packs.iterdir(), key=lambda p: tuple(int(v) for v in p.name.split(".")))
        reference = versions[-1]
        framework = "net" + ".".join(reference.name.split(".")[:2])
        test = stage / (manifest["id"] + ".PolicyTests.dll")
        arguments = ["dotnet", str(compiler), "-noconfig", "-nostdlib+", "-target:exe",
                     "-deterministic+", "-warnaserror+", "-out:" + str(test)]
        arguments += ["-r:" + str(p) for p in sorted((reference / "ref" / framework).glob("*.dll"))]
        arguments += [str(module / p) for p in settings["policySources"]]
        arguments += [str(root / p) for p in settings["policyTests"]]
        if subprocess.run(arguments).returncode:
            raise ValueError("Managed-Sicherheitsprüfung konnte nicht kompiliert werden.")
        test.with_suffix(".runtimeconfig.json").write_text(json.dumps({"runtimeOptions": {
            "tfm": framework, "framework": {"name": "Microsoft.NETCore.App", "version": reference.name}}}))
        subprocess.run(["dotnet", str(test)], check=True)

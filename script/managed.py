# SPDX-License-Identifier: GPL-3.0-only
"""Compile a module's own C# into an embedded image; never copy game assemblies."""
import hashlib
import json
import os
from pathlib import Path
import subprocess


def compile_managed(module, manifest, config, stage):
    settings = config.get("managed")
    if not settings:
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
    sdks = subprocess.check_output(["dotnet", "--list-sdks"], text=True).splitlines()
    if not sdks:
        raise ValueError("Lokales .NET SDK für C#-Trainer erforderlich.")
    sdk = sdks[-1]
    compiler = Path(sdk.split("[", 1)[1].rstrip("]")) / sdk.split()[0] / "Roslyn/bincore/csc.dll"
    refs = bundle / settings["referenceDirectory"]
    output = stage / (manifest["id"] + ".Managed.dll")
    args = ["dotnet", str(compiler), "-noconfig", "-nostdlib+", "-target:library",
            "-deterministic+", "-optimize+", "-warnaserror+", "-langversion:9",
            "-out:" + str(output)]
    args += ["-r:" + str(p) for p in sorted(refs.glob("*.dll"))]
    args += [str(module / p) for p in settings["sources"]]
    if subprocess.run(args).returncode:
        raise ValueError("Eigener Managed-Trainer konnte nicht kompiliert werden.")
    data = output.read_bytes()
    header = stage / settings["header"]
    header.write_text("// Generated in external build stage from this module's own C# only.\n"
                      "static const unsigned char MHTManagedImage[]={\n" +
                      ",\n".join(",".join(str(b) for b in data[i:i+32]) for i in range(0, len(data), 32)) +
                      "\n};\n")
    if settings.get("policyTests"):
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

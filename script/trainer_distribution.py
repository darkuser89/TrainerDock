#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Plan selective builds and publish immutable trainer packages.

The last successfully published catalog is the baseline, never the preceding
commit. This file does not contain game code, game data or signing secrets.
All generated data belongs to the existing external build tree.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "darkuser89/TrainerDock"
BASE_URL = "https://github.com/" + REPOSITORY + "/releases/download/"
API_URL = "https://api.github.com/repos/" + REPOSITORY
CATALOG_TAG = "trainer-catalog"
CATALOG_URL = BASE_URL + CATALOG_TAG + "/catalog.json"
VERSION = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\Z")
TOKEN = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
SHA = re.compile(r"[a-f0-9]{64}\Z")
FILES = ("Module.json", "TrainerConfig.json", "Trainer.dylib", "LICENSE")
TEST_KEYS = {"testSuite", "nativeContractTests", "rendererTests", "testSupportSources"}
INCLUDE = re.compile(r'^\s*#\s*(?:include|import)\s*"([^"\n]+)"', re.M)


def version(value):
    match = VERSION.fullmatch(value) if isinstance(value, str) else None
    if not match:
        raise ValueError("Trainerversion muss MAJOR.MINOR.PATCH ohne führende Nullen sein.")
    return tuple(map(int, match.groups()))


def empty_catalog():
    return {"schemaVersion": 1, "moduleABI": 1, "modules": []}


def validate_catalog(catalog):
    if not isinstance(catalog, dict) or catalog.get("schemaVersion") != 1 or catalog.get("moduleABI") != 1:
        raise ValueError("Unbekannter Trainerkatalogvertrag.")
    modules = catalog.get("modules")
    if not isinstance(modules, list) or len(modules) > 512:
        raise ValueError("Ungültige Trainerliste.")
    seen = set()
    for module in modules:
        identifier = module.get("id", "")
        if not TOKEN.fullmatch(identifier) or identifier in seen or not isinstance(module.get("name"), str):
            raise ValueError("Doppelte oder ungültige Trainerkennung.")
        seen.add(identifier)
        versions = module.get("versions")
        if not isinstance(versions, list) or not versions or len(versions) > 256:
            raise ValueError("Ungültige Trainerversionen.")
        used = set()
        for item in versions:
            current = item.get("version")
            version(current)
            if current in used:
                raise ValueError("Doppelte Trainerversion.")
            used.add(current)
            expected = BASE_URL + f"trainer-{identifier}-v{current}/{identifier}-{current}.zip"
            if item.get("url") != expected or not SHA.fullmatch(item.get("sha256", "")) or not SHA.fullmatch(item.get("fingerprint", "")):
                raise ValueError("Fremde Downloadquelle oder ungültiger Hash.")
            if type(item.get("size")) is not int or not 0 < item["size"] <= 200 * 1024 * 1024:
                raise ValueError("Ungültige Trainerpaketgröße.")
            if item.get("moduleABI") != 1:
                raise ValueError("Unbekannte Trainerschnittstelle.")
            version(item.get("minimumLauncherVersion"))
            manifest = item.get("manifest")
            if not isinstance(manifest, dict) or manifest.get("id") != identifier or manifest.get("version") != current:
                raise ValueError("Trainerpaket und Katalog stimmen nicht überein.")
            if not isinstance(manifest.get("features"), list) or not manifest["features"] or not isinstance(manifest.get("profiles"), list) or not manifest["profiles"]:
                raise ValueError("Kein vollständiger echter Trainerkatalog.")
    return catalog


def read_catalog(path):
    data = Path(path).read_bytes()
    if len(data) > 8 * 1024 * 1024:
        raise ValueError("Trainerkatalog zu groß.")
    return validate_catalog(json.loads(data))


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json_bytes(value)
    if path.exists() and path.read_bytes() == data:
        return
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def get_json(url, token=None):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "TrainerDock-distribution"}
    if token and url.startswith(API_URL + "/"):
        headers["Authorization"] = "Bearer " + token
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
        data = response.read(8 * 1024 * 1024 + 1)
    if len(data) > 8 * 1024 * 1024:
        raise ValueError("GitHub-Metadaten überschreiten die erlaubte Größe.")
    return json.loads(data)


def fetch_catalog(token=None):
    """404 of the release means first publication; transport failures are fatal."""
    try:
        release = get_json(API_URL + "/releases/tags/" + CATALOG_TAG, token)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            release = None
        else:
            raise
    if release is None:
        result = empty_catalog()
    else:
        assets = {asset["name"]: asset for asset in release.get("assets", [])}
        asset = assets.get("catalog.json") or assets.get("catalog.previous.json")
        if not asset:
            if release.get("draft") and not assets:
                result = empty_catalog()
            else:
                raise ValueError("Katalogrelease vorhanden, aber kein bestätigter Katalog abrufbar.")
        else:
            result = validate_catalog(get_json(asset["browser_download_url"]))
    # If the stable App release succeeded but updating the index failed, its
    # verified asset metadata remains a confirmed build baseline on the retry.
    try:
        latest = get_json(API_URL + "/releases/latest", token)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    else:
        launcher = confirmed_launcher(latest)
        if launcher:
            result["launcher"] = launcher
    return result


def confirmed_launcher(release):
    tag = release.get("tag_name", "")
    marker = re.search(r"<!-- trainerdock-launcher-fingerprint:([a-f0-9]{64}) -->", release.get("body") or "")
    if release.get("draft") or release.get("prerelease") or not tag.startswith("v") or not VERSION.fullmatch(tag[1:]) or not marker:
        return None
    assets = {asset["name"]: asset for asset in release.get("assets", [])}
    for name in ("TrainerDock-macOS-arm64.zip", "SHA256SUMS"):
        asset = assets.get(name, {})
        if not re.fullmatch(r"sha256:[a-f0-9]{64}", asset.get("digest", "")) or type(asset.get("size")) is not int or asset["size"] <= 0:
            return None
    return {"version": tag[1:], "fingerprint": marker[1]}


def source_closure(paths, root=ROOT, include_roots=()):
    """Follow actual quoted local includes, including shared backend headers."""
    root = Path(root).resolve()
    pending = [Path(p).resolve() for p in paths]
    found = set()
    while pending:
        path = pending.pop()
        if path in found:
            continue
        if root not in path.parents or not path.is_file():
            raise ValueError("Fehlende oder fremde Projektabhängigkeit: " + str(path))
        found.add(path)
        if path.suffix not in (".m", ".mm", ".h", ".hpp", ".inc", ".c", ".cpp"):
            continue
        text = path.read_text()
        for relative in INCLUDE.findall(text):
            candidates = [path.parent / relative, *[Path(folder) / relative for folder in include_roots]]
            match = next((p.resolve() for p in candidates if p.is_file()), None)
            if match:
                pending.append(match)
            elif relative not in ("VSManagedImage.h", "DuckovManagedImage.h"):
                raise ValueError("Nicht auflösbare lokale Abhängigkeit: " + relative + " in " + str(path))
    return sorted(found)


def digest_inputs(paths, metadata, root=ROOT):
    root = Path(root).resolve()
    digest = hashlib.sha256(json.dumps(metadata, sort_keys=True, separators=(",", ":")).encode())
    for path in sorted(paths):
        digest.update(str(path.relative_to(root)).encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def module_fingerprint(module, root=ROOT):
    module, root = Path(module), Path(root)
    config = json.loads((module / "Build.json").read_text())
    source = (module / config.get("sourceRoot", "Sources")).resolve()
    starts = [source / name for name in config["sources"]]
    starts += [root / "ModuleSDK" / name for name in config.get("sdkSources", [])]
    starts += [root / "ModuleSDK/MHTProtocol.m", root / "Config/TrainerDock.xcconfig", source / "LICENSE"]
    # Build infrastructure changes may affect flags, linkage or the package
    # contract. Application sources and unrelated trainers are never included.
    starts += [root / "script" / name for name in ("build.py", "xcode_project.py", "xcode_support.py")]
    metadata = {"module": json.loads((module / "Module.json").read_text()),
                "build": {key: value for key, value in config.items() if key not in TEST_KEYS}, "moduleABI": 1}
    if config.get("managed"):
        starts += [module / name for name in config["managed"]["sources"]]
        starts.append(root / "script/managed.py")
        lock = json.loads((root / "Config/ManagedImages.json").read_text())
        metadata["managedImage"] = lock["modules"][module.name]
    return digest_inputs(source_closure(starts, root, (source, root / "ModuleSDK")), metadata, root)


def launcher_fingerprint(root=ROOT):
    root = Path(root)
    starts = [p for folder in ("App", "Core") for p in (root / folder).glob("*.m")]
    starts += [root / "ModuleSDK/MHTProtocol.m", root / "Config/TrainerDock.xcconfig", root / "Config/Info.plist",
               root / "App/Resources/TrainerDock.png", root / "LICENSE"]
    starts += [root / "script" / name for name in ("build.py", "xcode_project.py", "xcode_support.py", "release.py")]
    return digest_inputs(source_closure(starts, root, (root / "App", root / "Core", root / "ModuleSDK")), {"launcherABI": 1}, root)


def next_version(configured, versions, reserved=()):
    base = version(configured)
    old = max([version(item["version"]) for item in versions] + [version(item) for item in reserved], default=(-1, -1, -1))
    return configured if base > old else ".".join(map(str, (old[0], old[1], old[2] + 1)))


def plan(catalog, root=ROOT, reserved=None):
    validate_catalog(catalog)
    root = Path(root)
    by_id = {module["id"]: module for module in catalog["modules"]}
    changed = []
    all_modules = []
    for path in sorted((root / "Modules").glob("*/Module.json")):
        config = json.loads((path.parent / "Build.json").read_text())
        if config.get("developmentOnly"):
            continue
        manifest = json.loads(path.read_text())
        identifier = manifest["id"]
        fingerprint = module_fingerprint(path.parent, root)
        previous = by_id.get(identifier, {}).get("versions", [])
        latest = max(previous, key=lambda item: version(item["version"]), default=None)
        all_modules.append(identifier)
        if latest and latest["fingerprint"] == fingerprint:
            continue
        changed.append({"id": identifier, "name": manifest["name"], "fingerprint": fingerprint,
                        "version": next_version(manifest["version"], previous, (reserved or {}).get(identifier, ()))})
    fingerprint = launcher_fingerprint(root)
    return {"schemaVersion": 1, "launcher": {"changed": catalog.get("launcher", {}).get("fingerprint") != fingerprint,
                                             "fingerprint": fingerprint}, "modules": changed,
            "allModules": all_modules, "baselineSHA256": hashlib.sha256(json_bytes(catalog)).hexdigest()}


def package_module(build_root, item):
    """Create one deterministic archive from the real built, verified runtime."""
    import build
    from xcode_support import verify_products
    build_root = build.external_build_path(build_root)
    identifier, current = item["id"], item["version"]
    if not TOKEN.fullmatch(identifier) or not SHA.fullmatch(item["fingerprint"]):
        raise ValueError("Ungültiger Bauauftrag.")
    version(current)
    source = ROOT / "Modules" / identifier
    if module_fingerprint(source) != item["fingerprint"]:
        raise ValueError("Trainerquellen haben sich seit der Planung geändert.")
    verify_products(build_root, identifier)
    package = build_root / "Modules" / (identifier + ".mhtmodule")
    for name in FILES:
        if (package / name).is_symlink() or not (package / name).is_file():
            raise ValueError("Ungültige Trainerdatei.")
    receipt = json.loads((build_root / "BuildFingerprints" / (identifier + ".json")).read_text())
    if receipt.get("fingerprint") != item["fingerprint"] or receipt.get("sha256") != hashlib.sha256((package / "Trainer.dylib").read_bytes()).hexdigest():
        raise ValueError("Trainerprodukt gehört nicht zu den aktuell geprüften Quellen; Trainer neu bauen.")
    manifest = json.loads((package / "Module.json").read_text())
    if manifest["id"] != identifier or not manifest.get("features"):
        raise ValueError("Kein echter erzeugter Trainerkatalog.")
    expected = json.loads((source / "Module.json").read_text())
    if any(manifest.get(key) != value for key, value in expected.items() if key != "features"):
        raise ValueError("Erzeugter Trainerkatalog stammt nicht aus der aktuellen Quelldefinition.")
    manifest["version"], manifest["moduleABI"] = current, 1
    configuration = json.loads((package / "TrainerConfig.json").read_text())
    configuration["app"]["version"] = current
    if configuration["profiles"] != manifest["profiles"]:
        raise ValueError("Trainerprofil und Runtimekonfiguration weichen ab.")
    data = {"Module.json": json_bytes(manifest), "TrainerConfig.json": json_bytes(configuration)}
    for name in ("Trainer.dylib", "LICENSE"):
        path = package / name
        if path.is_symlink() or not path.is_file():
            raise ValueError("Ungültige Trainerdatei.")
        data[name] = path.read_bytes()
    destination = build_root / "Distribution/Trainers"
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / f"{identifier}-{current}.zip"
    with tempfile.NamedTemporaryFile(dir=destination, suffix=".zip", delete=False) as raw:
        temporary = Path(raw.name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as writer:
            for name in FILES:
                entry = zipfile.ZipInfo(identifier + ".mhtmodule/" + name, (1980, 1, 1, 0, 0, 0))
                entry.create_system = 3
                entry.external_attr = (0o100755 if name == "Trainer.dylib" else 0o100644) << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                writer.writestr(entry, data[name])
        if archive.exists() and archive.read_bytes() != temporary.read_bytes():
            raise ValueError("Unveränderliches Trainerpaket existiert bereits mit anderen Bytes.")
        temporary.replace(archive)
    finally:
        temporary.unlink(missing_ok=True)
    config = json.loads((source / "Build.json").read_text())
    record = dict(version=current, fingerprint=item["fingerprint"],
                  url=BASE_URL + f"trainer-{identifier}-v{current}/{archive.name}",
                  sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), size=archive.stat().st_size,
                  minimumLauncherVersion="1.0.0", moduleABI=1,
                  architecture=config.get("architecture", "arm64"), manifest=manifest)
    write_json(destination / (archive.stem + ".json"), record)
    return record


def record_verified_build(build_root, identifier):
    """Only called after the real native product and all its checks succeeded."""
    library = Path(build_root) / "Modules" / (identifier + ".mhtmodule/Trainer.dylib")
    write_json(Path(build_root) / "BuildFingerprints" / (identifier + ".json"), {
        "fingerprint": module_fingerprint(ROOT / "Modules" / identifier),
        "sha256": hashlib.sha256(library.read_bytes()).hexdigest()})


def merged_catalog(previous, records):
    result = copy.deepcopy(validate_catalog(previous))
    by_id = {module["id"]: module for module in result["modules"]}
    for identifier, record in records.items():
        module = by_id.get(identifier)
        if module is None:
            module = {"id": identifier, "name": record["manifest"]["name"], "versions": []}
            result["modules"].append(module)
            by_id[identifier] = module
        same = next((item for item in module["versions"] if item["version"] == record["version"]), None)
        if same and same != record:
            raise ValueError("Eine veröffentlichte Trainerversion darf nicht ersetzt werden.")
        if not same:
            module["versions"].append(record)
        module["name"] = record["manifest"]["name"]
        module["versions"].sort(key=lambda item: version(item["version"]), reverse=True)
    result["modules"].sort(key=lambda item: item["id"])
    return validate_catalog(result)


class GitHub:
    def __init__(self, token, commit):
        if not token:
            raise ValueError("GitHub-Veröffentlichung benötigt den vorhandenen Repositoryzugang.")
        self.token, self.commit = token, commit

    def request(self, path, method="GET", payload=None, binary=None):
        url = path if path.startswith("https://") else API_URL + path
        if not (url.startswith(API_URL + "/") or url.startswith("https://uploads.github.com/repos/" + REPOSITORY + "/")):
            raise ValueError("Fremdes GitHub-Ziel.")
        headers = {"Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json",
                   "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "TrainerDock-distribution"}
        data = binary if binary is not None else json.dumps(payload).encode() if payload is not None else None
        if data is not None:
            headers["Content-Type"] = "application/octet-stream" if binary is not None else "application/json"
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=120) as response:
            return json.load(response) if response.status != 204 else None

    def release(self, tag, body):
        try:
            return self.request("/releases/tags/" + tag)
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
        return self.request("/releases", "POST", {"tag_name": tag, "target_commitish": self.commit,
                            "name": tag, "body": body, "draft": True, "prerelease": True, "make_latest": "false"})

    def upload(self, release, name, data):
        asset = next((asset for asset in release.get("assets", []) if asset["name"] == name), None)
        digest = "sha256:" + hashlib.sha256(data).hexdigest()
        if asset:
            if asset.get("digest") != digest or asset.get("size") != len(data):
                raise ValueError("Vorhandenes Release-Asset darf nicht überschrieben werden.")
            return asset
        asset = self.request(release["upload_url"].split("{", 1)[0] + "?name=" + urllib.parse.quote(name), "POST", binary=data)
        if asset.get("digest") != digest or asset.get("size") != len(data):
            raise ValueError("GitHub bestätigt nicht die erwarteten Paketbytes.")
        return asset

    def publish_trainers(self, previous, records, distribution):
        fresh = fetch_catalog(self.token)
        if hashlib.sha256(json_bytes(fresh)).hexdigest() != hashlib.sha256(json_bytes(previous)).hexdigest():
            raise ValueError("Der veröffentlichte Katalog wurde während des Builds geändert; neu planen.")
        for identifier, item in records.items():
            body = "TrainerDock-Trainer.\n\n<!-- trainerdock-fingerprint:" + item["fingerprint"] + " -->"
            release = self.release(f"trainer-{identifier}-v{item['version']}", body)
            if body != release.get("body"):
                raise ValueError("Trainertag gehört zu einem anderen Quellstand.")
            archive = Path(distribution) / f"{identifier}-{item['version']}.zip"
            data = archive.read_bytes()
            if hashlib.sha256(data).hexdigest() != item["sha256"] or len(data) != item["size"]:
                raise ValueError("Trainerpaket nach Prüfung geändert.")
            self.upload(release, archive.name, data)
            if release["draft"]:
                self.request("/releases/" + str(release["id"]), "PATCH", {"draft": False, "prerelease": True, "make_latest": "false"})
        result = merged_catalog(previous, records)
        self.publish_catalog(result)
        return result

    def publish_catalog(self, catalog):
        data = json_bytes(validate_catalog(catalog))
        release = self.release(CATALOG_TAG, "TrainerDock-Katalog. Trainerpakete bleiben unverändert in eigenen Releases.")
        assets = {asset["name"]: asset for asset in release.get("assets", [])}
        old, backup = assets.get("catalog.json"), assets.get("catalog.previous.json")
        if not old and backup:
            old = self.request("/releases/assets/" + str(backup["id"]), "PATCH", {"name": "catalog.json"})
            backup = None
        digest = "sha256:" + hashlib.sha256(data).hexdigest()
        if old and old.get("digest") == digest:
            return
        if backup:
            self.request("/releases/assets/" + str(backup["id"]), "DELETE")
        staged_name = "catalog-next-" + hashlib.sha256(data).hexdigest() + ".json"
        staged = self.upload(release, staged_name, data)
        moved_old = False
        try:
            if old:
                self.request("/releases/assets/" + str(old["id"]), "PATCH", {"name": "catalog.previous.json"})
                moved_old = True
            self.request("/releases/assets/" + str(staged["id"]), "PATCH", {"name": "catalog.json"})
            if release["draft"]:
                self.request("/releases/" + str(release["id"]), "PATCH", {"draft": False, "prerelease": True, "make_latest": "false"})
            confirmed = validate_catalog(get_json(CATALOG_URL))
            if json_bytes(confirmed) != data:
                raise ValueError("Veröffentlichter Katalog stimmt nicht mit den geprüften Bytes überein.")
        except Exception:
            # Keep the last confirmed catalog available on both ordinary failure
            # and a subsequent retry after an interrupted rename transaction.
            abandoned = []
            if moved_old:
                current = self.request("/releases/tags/" + CATALOG_TAG)
                for asset in current["assets"]:
                    if asset["name"] == "catalog.json":
                        self.request("/releases/assets/" + str(asset["id"]), "PATCH", {"name": "catalog-failed-" + str(asset["id"]) + ".json"})
                        abandoned.append(asset["id"])
                self.request("/releases/assets/" + str(old["id"]), "PATCH", {"name": "catalog.json"})
                for asset_id in set(abandoned + [staged["id"]]):
                    self.request("/releases/assets/" + str(asset_id), "DELETE")
            raise
        if old:
            self.request("/releases/assets/" + str(old["id"]), "DELETE")


def bootstrap(build_root, destination):
    """No synthetic hashes or unavailable pretend packages enter the app."""
    explicit = os.environ.get("TRAINERDOCK_CATALOG_FILE")
    cached = Path(build_root) / "Catalog/catalog.json"
    catalog = read_catalog(explicit) if explicit else read_catalog(cached) if cached.is_file() else empty_catalog()
    write_json(destination, catalog)


def external_path(raw):
    from build import external_build_path
    return external_build_path(raw)


def prepare_build_root(root):
    """Establish ownership before planning creates Catalog/Distribution on CI."""
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    marker = root / ".trainerdock-build"
    if not marker.exists() and any(root.iterdir()):
        raise ValueError("Nichtleeren fremden Buildordner nicht übernehmen.")
    marker.touch()


def reserved_versions():
    """Never reuse a tag left by an interrupted or failed publication."""
    tags = subprocess.check_output(["git", "ls-remote", "--tags", "origin"], cwd=ROOT, text=True)
    result = {}
    for line in tags.splitlines():
        match = re.search(r"refs/tags/trainer-([a-z0-9]+(?:-[a-z0-9]+)*)-v([0-9.]+)$", line)
        if match and VERSION.fullmatch(match[2]):
            result.setdefault(match[1], []).append(match[2])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("plan", "package", "publish-trainers", "publish-launcher"))
    parser.add_argument("--build-dir", default=str(Path.home() / "Library/Developer/TrainerDock"))
    parser.add_argument("--catalog", type=Path, help="Explicit confirmed baseline; otherwise download from GitHub")
    parser.add_argument("--commit", default=os.environ.get("GITHUB_SHA", "main"))
    args = parser.parse_args()
    root = external_path(args.build_dir)
    if args.action == "plan":
        prepare_build_root(root)
    distribution = root / "Distribution"
    distribution.mkdir(parents=True, exist_ok=True)
    baseline_file, plan_file = distribution / "baseline.json", distribution / "plan.json"
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if args.action == "plan":
        previous = read_catalog(args.catalog) if args.catalog else fetch_catalog(token)
        result = plan(previous, reserved=reserved_versions() if not args.catalog else None)
        write_json(baseline_file, previous)
        write_json(plan_file, result)
        write_json(root / "Catalog/catalog.json", previous)
        output = os.environ.get("GITHUB_OUTPUT")
        if output:
            with open(output, "a") as stream:
                stream.write("launcher_changed=" + str(result["launcher"]["changed"]).lower() + "\n")
                stream.write("modules=" + json.dumps([item["id"] for item in result["modules"]], separators=(",", ":")) + "\n")
                stream.write("any_changed=" + str(result["launcher"]["changed"] or bool(result["modules"])).lower() + "\n")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return
    previous = read_catalog(baseline_file)
    result = json.loads(plan_file.read_text())
    if args.action == "package":
        records = {item["id"]: package_module(root, item) for item in result["modules"]}
        write_json(distribution / "trainer-records.json", records)
        return
    records = json.loads((distribution / "trainer-records.json").read_text())
    github = GitHub(token, args.commit)
    if args.action == "publish-trainers":
        updated = github.publish_trainers(previous, records, distribution / "Trainers")
        write_json(root / "Catalog/catalog.json", updated)
        write_json(distribution / "published-catalog.json", updated)
        return
    if not result["launcher"]["changed"]:
        print("Launcher unverändert; keine Veröffentlichung.")
        return
    archive = distribution / "TrainerDock-macOS-arm64.zip"
    metadata = json.loads((distribution / "launcher-record.json").read_text())
    version(metadata["version"])
    archive_data = archive.read_bytes()
    if metadata["sha256"] != hashlib.sha256(archive_data).hexdigest() or metadata["size"] != len(archive_data):
        raise ValueError("Launcherpaket nach Prüfung geändert.")
    tag = "v" + metadata["version"]
    body = "TrainerDock ohne gebündelte Trainer. Einzelne Trainer in der App laden.\n\n<!-- trainerdock-launcher-fingerprint:" + result["launcher"]["fingerprint"] + " -->"
    release = github.release(tag, body)
    if release.get("body") != body:
        raise ValueError("Bestehendes App-Release gehört zu einem anderen Quellstand.")
    github.upload(release, archive.name, archive_data)
    github.upload(release, "SHA256SUMS", (distribution / "SHA256SUMS").read_bytes())
    github.request("/releases/" + str(release["id"]), "PATCH", {"draft": False, "prerelease": False, "make_latest": "true"})
    updated = fetch_catalog(token)
    updated["launcher"] = {"version": metadata["version"], "fingerprint": result["launcher"]["fingerprint"]}
    github.publish_catalog(updated)
    write_json(root / "Catalog/catalog.json", updated)


if __name__ == "__main__":
    main()

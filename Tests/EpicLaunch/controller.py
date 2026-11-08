#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Test-only, single Epic launch. Default is a read-only plan; --run needs prior consent."""
import argparse
import base64
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import tempfile
import time
from urllib.parse import quote

LIMIT = 1024 * 1024
LIBPROC = None


def pairs(values):
    result = {}
    for key, value in values:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def load(data):
    value = json.loads(data, object_pairs_hook=pairs)
    if not isinstance(value, dict):
        raise ValueError("JSON object required")
    return value


def read(path, private=False):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        s = os.fstat(fd)
        if not stat.S_ISREG(s.st_mode) or s.st_uid != os.getuid() or s.st_size > LIMIT:
            raise ValueError("unsafe or oversized input")
        if private and s.st_mode & 0o077:
            raise ValueError("private input must have mode 0600")
        data = os.read(fd, LIMIT + 1)
        if len(data) > LIMIT:
            raise ValueError("oversized input")
        return data
    finally:
        os.close(fd)


def encode(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=True).encode()


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic(path, data, mode=0o600):
    path = Path(path)
    fd, temporary = tempfile.mkstemp(prefix=".trainerdock-", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_directory(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def replace_string(data, key, replacement):
    """Replace one top-level JSON string, preserving every other original byte."""
    document = load(data)
    if not isinstance(document.get(key), str):
        raise ValueError("expected string field missing")
    text = data.decode("utf-8")
    decoder = json.JSONDecoder(object_pairs_hook=pairs)
    at = 1 + len(text) - len(text.lstrip())
    while True:
        while text[at].isspace():
            at += 1
        name, end = decoder.raw_decode(text, at)
        at = end
        while text[at].isspace():
            at += 1
        if text[at] != ":":
            raise ValueError("invalid JSON")
        at += 1
        while text[at].isspace():
            at += 1
        start = at
        _, at = decoder.raw_decode(text, at)
        if name == key:
            return (text[:start] + json.dumps(replacement) + text[at:]).encode("utf-8")
        while text[at].isspace():
            at += 1
        if text[at] != ",":
            raise ValueError("field missing")
        at += 1


def digest(path):
    with open(path, "rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def process_paths():
    """Process identities only. Never request command arguments or environments."""
    global LIBPROC
    if LIBPROC is None:
        LIBPROC = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        LIBPROC.proc_listallpids.argtypes = [ctypes.c_void_p, ctypes.c_int]
        LIBPROC.proc_listallpids.restype = ctypes.c_int
        LIBPROC.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
        LIBPROC.proc_pidpath.restype = ctypes.c_int
    count = LIBPROC.proc_listallpids(None, 0)
    if count <= 0:
        raise ValueError("cannot inspect process identities")
    pids = (ctypes.c_int * (count + 512))()
    count = LIBPROC.proc_listallpids(pids, ctypes.sizeof(pids))
    if count <= 0 or count >= len(pids):
        raise ValueError("incomplete process identities")
    result = {}
    for pid in pids[:count]:
        path = ctypes.create_string_buffer(4096)
        if LIBPROC.proc_pidpath(pid, path, len(path)) > 0:
            result[pid] = os.fsdecode(path.value)
    return result


def validate(spec, launch):
    required = {"manifest", "appName", "namespace", "install", "launchExecutable", "targetSHA256"}
    if set(spec) != required or any(not isinstance(value, str) or not value or "\x00" in value for value in spec.values()):
        raise ValueError("invalid test specification")
    manifest = Path(spec["manifest"])
    if not manifest.is_absolute() or manifest.suffix != ".item" or manifest.resolve() != manifest:
        raise ValueError("manifest must be a canonical .item file")
    original = read(manifest)
    item = load(original)
    if item.get("AppName") != spec["appName"] or item.get("CatalogNamespace") != spec["namespace"]:
        raise ValueError("Epic identity differs from the approved specification")
    if item.get("InstallLocation") != spec["install"] or item.get("LaunchExecutable") != spec["launchExecutable"]:
        raise ValueError("Epic installation differs from the approved specification")
    # This probe does not consume or retain any custom launch/auth arguments.
    if item.get("LaunchCommand") != "":
        raise ValueError("probe requires an empty original LaunchCommand")
    if not isinstance(item.get("CatalogItemId"), str) or not item["CatalogItemId"] or len(item["CatalogItemId"]) > 256:
        raise ValueError("missing Epic catalog identity")
    relative = Path(spec["launchExecutable"])
    install = Path(spec["install"])
    if not install.is_absolute() or install.resolve() != install or relative.is_absolute() or ".." in relative.parts or "\\" in str(relative):
        raise ValueError("unsafe installation/executable path")
    target = install / relative
    if target.resolve() != target or not target.is_file() or not os.access(target, os.X_OK) or digest(target) != spec["targetSHA256"]:
        raise ValueError("original executable identity mismatch")
    if set(launch) != {"target", "environment"} or launch["target"] != str(target):
        raise ValueError("private launch target mismatch")
    env = launch["environment"]
    if not isinstance(env, dict) or not env or len(env) > 32:
        raise ValueError("invalid own trainer environment")
    for key, value in env.items():
        if not isinstance(key, str) or not isinstance(value, str) or not key or "=" in key or "\x00" in key + value or len(key) > 128 or len(value) > 8192:
            raise ValueError("invalid own trainer environment")
        if not (key.startswith("MHT_") or key in {"DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH"}):
            raise ValueError("only own MHT/DYLD settings are accepted")
    if env.get("MHT_TARGET") != str(target) or not env.get("DYLD_INSERT_LIBRARIES"):
        raise ValueError("missing own trainer binding")
    return original, target


def restore(journal):
    path = Path(journal["manifest"])
    original = base64.b64decode(journal["original"], validate=True)
    changed = base64.b64decode(journal["changed"], validate=True)
    current = read(path)
    if current == original:
        return True
    if current != changed:
        return False  # Preserve any newer Epic/user mutation; journal remains for review.
    atomic(path, original, journal["mode"])
    return True


def cleanup(journal, identities=process_paths):
    broker = journal["broker"]
    if broker in identities().values():
        return False
    for field in ("sidecar", "broker"):
        path = Path(journal[field])
        if path.exists():
            if path.is_symlink() or digest(path) != journal[field + "SHA256"]:
                return False
            path.unlink()
    receipt = Path(journal["receipt"])
    if receipt.exists() and not receipt.is_symlink():
        receipt.unlink()
    sync_directory(Path(broker).parent)
    return True


def recover(path, identities=process_paths):
    journal = load(read(path, private=True))
    if not restore(journal):
        raise ValueError("manifest changed externally; retained journal and probe files")
    if not cleanup(journal, identities):
        raise ValueError("probe still loaded or modified; retained journal and probe files")
    Path(path).unlink()
    sync_directory(Path(path).parent)


def recover_cli(path):
    work = Path(path).parent
    if work.resolve() != work or work.stat().st_uid != os.getuid() or work.stat().st_mode & 0o077:
        raise ValueError("unsafe recovery directory")
    lock = os.open(work / "lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        recover(path)
    finally:
        os.close(lock)


def run(spec, launch, original, target, broker_source, work, timeout):
    work.mkdir(mode=0o700, parents=True, exist_ok=True)
    if work.is_symlink() or work.stat().st_uid != os.getuid() or work.stat().st_mode & 0o077:
        raise ValueError("work directory must be private and owned by the user")
    lock = os.open(work / "lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        journal_path = work / "transaction.json"
        if journal_path.exists():
            raise ValueError("recover the previous transaction before another attempt")
        if str(target) in process_paths().values():
            raise ValueError("original game already running; no second launch")
        name = "TrainerDock-EpicProbe-" + os.urandom(12).hex()
        broker = Path(spec["install"]) / name
        sidecar = Path(str(broker) + ".json")
        mark = work / "receipt.json"
        if mark.exists():
            raise ValueError("unexpected existing receipt")
        own = read(broker_source)
        if own[:4] not in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe"):
            raise ValueError("broker must be the compiled native test executable")
        config = encode(dict(launch, targetSHA256=spec["targetSHA256"], receipt=str(mark), expires=time.time() + timeout + 10, nonce=name))
        if len(config) > 65536:
            raise ValueError("private broker configuration too large")
        changed = replace_string(original, "LaunchExecutable", name)
        journal = dict(manifest=spec["manifest"], original=base64.b64encode(original).decode(), changed=base64.b64encode(changed).decode(),
                       mode=stat.S_IMODE(Path(spec["manifest"]).stat().st_mode), broker=str(broker), sidecar=str(sidecar), receipt=str(mark),
                       brokerSHA256=hashlib.sha256(own).hexdigest(), sidecarSHA256=hashlib.sha256(config).hexdigest())
        atomic(journal_path, encode(journal))  # Durable rollback bytes precede every mutation.
        outcome = "timeout"
        try:
            for path, data, mode in ((broker, own, 0o700), (sidecar, config, 0o600)):
                fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
                with os.fdopen(fd, "wb") as stream:
                    stream.write(data); stream.flush(); os.fsync(stream.fileno())
            sync_directory(broker.parent)
            if read(spec["manifest"]) != original:
                raise ValueError("manifest changed before launch; not overwritten")
            atomic(spec["manifest"], changed, journal["mode"])
            uri = "com.epicgames.launcher://apps/" + quote(spec["namespace"] + ":" + load(original)["CatalogItemId"] + ":" + spec["appName"], safe="") + "?action=launch&silent=true"
            subprocess.run(["/usr/bin/open", "-b", "com.epicgames.EpicGamesLauncher", uri], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            until = time.monotonic() + timeout
            while time.monotonic() < until:
                if mark.exists():
                    result = load(read(mark, private=True))
                    # Restore immediately at the first broker acknowledgement. Do not
                    # keep Epic redirected during authentication or the game test.
                    if not restore(journal):
                        raise ValueError("external manifest change; retained rollback journal")
                    if result.get("state") == "exec-failed":
                        outcome = "exec-failed"; break
                    pid = result.get("pid")
                    if result.get("state") == "exec-attempt" and isinstance(pid, int) and pid > 0 and process_paths().get(pid) == str(target):
                        outcome = "original-exec-confirmed"; break
                time.sleep(0.1)
        finally:
            recover(journal_path)
        return outcome
    finally:
        os.close(lock)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--config", type=Path, help="private own target/environment JSON, mode 0600")
    parser.add_argument("--broker", type=Path)
    parser.add_argument("--work-dir", type=Path, default=Path("/private/tmp/trainerdock-epic-launch-test") / str(os.getuid()))
    parser.add_argument("--timeout", type=int, default=45)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--run", action="store_true", help="only after explicit user authorization for this exact metadata transaction")
    mode.add_argument("--plan", action="store_true", help="read-only plan (default)")
    parser.add_argument("--recover", type=Path, help="restore a previous transaction; never launch")
    args = parser.parse_args()
    if args.recover:
        recover_cli(args.recover)
        print("Recovered the exact original manifest and removed the unloaded probe.")
        return
    if not all((args.spec, args.config, args.broker)) or not 5 <= args.timeout <= 120:
        parser.error("--spec, --config and --broker are required; timeout must be 5..120")
    spec, launch = load(read(args.spec)), load(read(args.config, private=True))
    original, target = validate(spec, launch)
    if not args.run:
        print(json.dumps({"mode": "read-only-plan", "manifest": spec["manifest"], "target": str(target),
                          "mutation": "LaunchExecutable only; temporary own broker beside the app", "starts": 1,
                          "clientRestart": False, "authArguments": "opaque forward only; never logged or stored"}, indent=2))
        return
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda number, frame: (_ for _ in ()).throw(InterruptedError("interrupted")))
    print(run(spec, launch, original, target, args.broker, args.work_dir, args.timeout))
    print("exec confirmation is not an authentication, menu, or cheat-effect confirmation.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError, InterruptedError):
        # Exception representations may include user-configured values: never print them.
        raise SystemExit("Epic probe stopped. Check the private transaction journal; no argument values are logged.")

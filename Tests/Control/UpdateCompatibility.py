#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only regression checks for MAS 1.371 against the supported Steam ABI.

Real original files are inspected, never modified or launched. This is static
binding/layout evidence, not proof of an in-game effect.
"""
import argparse
import re
import struct
import subprocess
from pathlib import Path

from BinaryMap import Mach

ROOT = Path(__file__).resolve().parents[2]
UUIDS = ["DB36B7EC-1D93-3FF4-9737-46E9D6F7082F", "4A3DF4E6-269E-3603-BFE3-62017FE33B4B",
         "459E81A6-E3B5-347B-A287-94247A678E4D", "D6074A0B-5B60-3C32-8A64-0EB4D8A680D7",
         "8F10F489-537E-3D64-A8D9-406C50C534B1"]
TYPES = ["GameHealthComponentState", "AbilityResourceComponentState", "GameInventoryComponentState",
         "PlayerPropertiesComponentState", "PlayerAssistModeComponentState", "MovementSystemComponentState",
         "ArmorComponentState", "ItemStackComponentState", "LootDropItemComponentState", "GameServer"]


def require(value, note):
    if not value:
        raise ValueError(note)


def function_equal(old, new, a, b):
    lo, hi = old.bounds(old.base + a)
    start, end = new.bounds(new.base + b)
    return lo == old.base + a and start == new.base + b and old.normalized(lo, hi) == new.normalized(start, end)


def page_load(mach, offset):
    a, b = mach.words(mach.base + offset, mach.base + offset + 8)
    require(a & 0x9f000000 == 0x90000000 and b & 0xffc00000 == 0xf9400000
            and (a & 31) == ((b >> 5) & 31), "Expected original ADRP/LDR singleton load")
    immediate = (((a >> 5) & 0x7ffff) << 2) | ((a >> 29) & 3)
    if immediate & (1 << 20):
        immediate -= 1 << 21
    return ((mach.base + offset) & ~4095) + (immediate << 12) + ((b >> 10) & 4095) * 8 - mach.base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--steam", required=True, type=Path)
    parser.add_argument("--mas", required=True, type=Path)
    args = parser.parse_args()
    paths = [args.mas / "Contents/MacOS" / p for p in ("Game", "coregame.dylib", "app.dylib", "bonsai.dylib", "rl.dylib")]
    for path, expected in zip(paths, UUIDS):
        text = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(path)], text=True)
        require(re.findall(r"UUID: ([A-F0-9-]+) \(arm64\)", text) == [expected], f"Wrong original identity: {path.name}")
    old = Mach(args.steam / "Contents/MacOS/Game")
    require(old.base == 0x100000000, "Expected pinned Steam arm64 executable")
    steam_uuid = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(old.path)], text=True)
    require("CF65DC88-F5CE-38A4-8A2A-21FD5F43F14B" in steam_uuid, "Wrong Steam reference build")
    new = Mach(paths[0])
    source = (ROOT / "Modules/control/Sources/ControlEngine.mm").read_text()
    addresses = [(int(a, 16), int(b, 16), c == "true") for a, b, c in re.findall(
        r"\{(0x[0-9a-f]+),0x[0-9a-f]+,(0x[0-9a-f]+),(true|false)\}", source)]
    require(len(addresses) == 21, "Complete MAS address table required")
    unchanged = 0
    for index, expected in enumerate(TYPES, 2):
        a, b, core = addresses[index]
        require(not core, "Component vtables must belong to the executable")
        for mach, offset in ((old, a), (new, b)):
            info = mach.pointer(mach.base + offset - 8)
            name = mach.string(mach.pointer(info + 8))
            require(name == str(len(expected)) + expected, f"Wrong RTTI for {expected}")
        same = 0
        for slot in range(32):
            before = old.pointer(old.base + a + slot * 8) - old.base
            after = new.pointer(new.base + b + slot * 8) - new.base
            try:
                same += bool(function_equal(old, new, before, after))
            except (ValueError, struct.error):
                pass
        require(same >= (18 if expected == "GameServer" else 29), f"Changed component method layout: {expected}")
        unchanged += same
    require(new.pointer(new.base + addresses[11][1] + 7 * 8) - new.base == addresses[12][1], "Wrong GameServer update slot")
    for index in (0, 1, 13, 14):
        require(function_equal(old, new, addresses[index][0], addresses[index][1]), "Changed pin or health setter layout")
    require(function_equal(old, new, 0x4f0b84, 0x4eae64), "Changed original infinite-ammo caller")
    branch = new.words(new.base + 0x4eae8c, new.base + 0x4eae90)[0]
    relative = branch & 0x3ffffff
    if relative & (1 << 25):
        relative -= 1 << 26
    require(branch & 0xfc000000 == 0x14000000 and 0x4eae8c + relative * 4 == addresses[1][1], "Wrong +8-handle pin notifier")
    require(function_equal(old, new, 0x7f4c58, 0x7ded50), "Changed database singleton accessor")
    require(page_load(new, 0x7ded50) == addresses[15][1], "Wrong database singleton")
    core_symbols = {line.split()[-1]: int(line.split()[0], 16) for line in subprocess.check_output(
        ["nm", "-n", str(paths[1])], text=True).splitlines() if len(line.split()) == 3 and re.fullmatch(r"[0-9a-fA-F]{16}", line.split()[0])}
    for index, symbol in enumerate(("__ZN8coregame21LocalGameServerRunner12sm_pInstanceE",
                                   "__ZN8coregame14GameServerBase14getGameSessionEv",
                                   "__ZN8coregame17ServerGameSession27getSinglePlayerAvatarObjectEv",
                                   "__ZN8coregame10GameWindow12sm_pInstanceE", "__ZNK8coregame10GameWindow8getMouseEv"), 16):
        require(addresses[index][2] and core_symbols.get(symbol) == addresses[index][1], "Wrong original core API binding")
    print(f"PASS: five exact MAS identities, {unchanged} component-method layouts, native update slot, value pins, health setters, database and core API bindings. No game launched.")


if __name__ == "__main__":
    main()

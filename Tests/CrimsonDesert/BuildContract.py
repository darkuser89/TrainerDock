#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only checks for the pinned Steam build; never launches or modifies it."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Control'))
from BinaryMap import Mach

ROOT = Path(__file__).resolve().parents[2]


def require(value, message):
    if not value:
        raise ValueError(message)


def page_pair(mach, offset, load=False):
    a, b = mach.words(mach.base + offset, mach.base + offset + 8)
    require(a & 0x9f000000 == 0x90000000 and (a & 31) == ((b >> 5) & 31), 'ADRP owner mismatch')
    immediate = (((a >> 5) & 0x7ffff) << 2) | ((a >> 29) & 3)
    if immediate & (1 << 20):
        immediate -= 1 << 21
    require(b & (0xffc00000 if load else 0xff800000) == (0xf9400000 if load else 0x91000000), 'Unexpected singleton/vtable instruction')
    return (offset & ~4095) + (immediate << 12) + ((b >> 10) & 4095) * (8 if load else 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    info = plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())
    require(info['CFBundleIdentifier'] == 'com.pearlabyss.CrimsonDesert.steam' and info['CFBundleVersion'] == '450', 'Wrong original build')
    mach = Mach(args.app / 'Contents/MacOS/CrimsonDesert_Steam')
    identity = subprocess.check_output(['xcrun', 'dwarfdump', '--uuid', str(mach.path)], text=True)
    require('6D8EEB01-C410-39A0-8460-D3CDAE923532 (arm64)' in identity, 'Wrong original UUID')
    subprocess.run(['codesign', '--verify', '--strict', str(args.app)], check=True)
    source = ROOT / 'Modules/crimson-desert/Sources'
    header = (source / 'CrimsonBuild.h').read_text()
    probes = {int(a, 16): bytes(int(v, 16) for v in re.findall(r'0x[0-9a-f]+', b))
              for a, b in re.findall(r'\{(0x[0-9a-f]+),\{([^}]+)\}\}', header)}
    require(len(probes) == 76, 'Incomplete native probes')
    for offset, expected in probes.items():
        require(len(expected) == 32 and mach.raw(mach.base + offset, 32) == expected, f'Changed original code: {offset:x}')
    native = (source / 'CrimsonNative.mm').read_text()
    effects = (source / 'CrimsonEffects.h').read_text()
    inventory = (source / 'CrimsonInventory.h').read_text()
    calls = {int(a, 16) for a in re.findall(r'native<[^;\n]+?>\((0x[0-9a-f]+)\)', native + effects + inventory)}
    require(calls <= probes.keys(), 'Native function without exact runtime guard')
    for offset, expected, load in [(0x7d9004, 0x8db0f30, True), (0x3fc8bbc, 0x8f72700, True),
                                   (0x893ff0, 0x8f8ba88, False), (0x408d49c, 0x8679c28, False),
                                   (0x29eb50, 0x80cd500, False), (0x495fd98, 0x9091cfc, False)]:
        require(page_pair(mach, offset, load) == expected, 'Changed global owner/type binding')
    for offset, expected in [(0x8679c28, 'N2pa18ClientTimerManagerE'),
                             (0x80cd500, 'N2pa14uiCommonScript39UIGamePlayControlRootInventoryEquipmentE')]:
        rtti = mach.pointer(mach.base + offset - 8)
        require(mach.string(mach.pointer(rtti + 8)) == expected, 'Wrong native owner RTTI')
    profile = json.loads((source.parent / 'Module.json').read_text())['profiles'][0]
    require(profile['uuids'] == ['6D8EEB01-C410-39A0-8460-D3CDAE923532'], 'Manifest/runtime identity mismatch')
    require('beginProbe' not in native and '.command.json' not in native, 'Test command handler must not ship')
    print(f'PASS: exact original identity/signature, {len(probes)} instruction guards, {len(calls)} guarded calls, six owner/type bindings and timer/inventory RTTI. No game launched.')


if __name__ == '__main__':
    main()

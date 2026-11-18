#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only checks for the pinned Steam build; never launches or modifies it."""
import argparse
import hashlib
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
    build = info['CFBundleVersion']
    require(info['CFBundleIdentifier'] == 'com.pearlabyss.CrimsonDesert.steam' and build in ('450', '466'), 'Wrong original build')
    mach = Mach(args.app / 'Contents/MacOS/CrimsonDesert_Steam')
    identity = subprocess.check_output(['xcrun', 'dwarfdump', '--uuid', str(mach.path)], text=True)
    uuid = {'450': '6D8EEB01-C410-39A0-8460-D3CDAE923532', '466': 'B5C91E74-E921-3891-A1E9-B9BAAB7D0A9D'}[build]
    require(uuid + ' (arm64)' in identity, 'Wrong original UUID')
    source = ROOT / 'Modules/crimson-desert/Sources'
    header = (source / 'CrimsonBuild.h').read_text()
    probes = {int(a, 16): bytes(int(v, 16) for v in re.findall(r'0x[0-9a-f]+', b))
              for a, b in re.findall(r'\{(0x[0-9a-f]+),\{([^}]+)\}\}', header)}
    require(len(probes) == 76, 'Incomplete native probes')
    relocated = {key: key for key in probes}
    profile = next(p for p in json.loads((source.parent / 'Module.json').read_text())['profiles'] if uuid in p['uuids'])
    require(profile['enabled'], 'New profile is not ready')
    if build == '450':
        subprocess.run(['codesign', '--verify', '--strict', str(args.app)], check=True)
    else:
        require(profile.get('steamBuildId') == '26636972' and profile.get('signatureScope') == 'sha256-original'
                and profile.get('integrityApproval') == 'user-confirmed-steam-original', 'Missing exact original approval')
        expected_files = set(profile['integrityFiles'])
        require(len(expected_files) == 4 and expected_files == {c['path'] for c in profile['fileChecks']}, 'Incomplete original files')
        for path in expected_files:
            original = args.app / path
            chunks = sorted((c for c in profile['fileChecks'] if c['path'] == path), key=lambda c: c['offset'])
            position = 0
            with original.open('rb') as stream:
                for chunk in chunks:
                    require(chunk['offset'] == position and chunk['fileSize'] == original.stat().st_size, 'Gap or changed file size')
                    data = stream.read(chunk['length'])
                    require(len(data) == chunk['length'] and hashlib.sha256(data).hexdigest() == chunk['sha256'], 'Changed original bytes')
                    position += len(data)
            require(position == original.stat().st_size, 'Incomplete original hash coverage')
        header466 = (source / 'CrimsonBuild466.h').read_text()
        entries = [(int(key, 16), int(offset, 16), bytes(int(v, 16) for v in re.findall(r'0x[0-9a-f]+', raw)))
                   for key, offset, raw in re.findall(r'\{(0x[0-9a-f]+),(0x[0-9a-f]+),\{([^}]+)\}\}', header466)]
        require(len(entries) == 75 and len({e[0] for e in entries}) == 75, 'Incomplete/duplicate 466 bindings')
        relocated = {key: offset for key, offset, _ in entries}
        probes = {offset: raw for _, offset, raw in entries}
        for old, expected in [(0x1ac8038, 0xd6), (0x1ac8010, 0xbe), (0x1ac8040, 0xd8), (0x1ac8020, 0xd0), (0x1ac8018, 0xce)]:
            words = mach.words(mach.base + relocated[old], mach.base + relocated[old] + 8)
            require(words == (0x79400000 | ((expected // 2) << 10), 0xd65f03c0), 'Wrong stat getter/layout')
    # A default DropValue constructor takes only x0. Reject copy constructors
    # even when their prologue looks nearby/similar: no x1 dereference or call.
    constructor = relocated[0x1f97c9c]
    require(mach.words(mach.base + constructor, mach.base + constructor + 16) ==
            (0xf900181f, 0x52800248, 0x79000008 if build == '466' else 0x39000008, 0xd65f03c0),
            'Wrong no-argument DropValue constructor ABI')
    if build == '466':
        money_getter = relocated[0x195676c]
        words = mach.words(mach.base + money_getter, mach.base + money_getter + 28)
        require(words[:3] == (0xa9bf7bfd, 0x910003fd, 0x52800880)
                and words[4:] == (0x7940f000, 0xa8c17bfd, 0xd65f03c0), 'Wrong money-inventory kind getter ABI')
        mapping = relocated[0x1a80ee0]
        words = mach.words(mach.base + mapping, mach.base + mapping + 24)
        require(words[0] & 0xfc000000 == 0x94000000 and
                mapping + ((words[0] & 0x3ffffff) - (1 << 26)) * 4 == money_getter and
                words[1:] == (0x12003c08, 0x6b37211f, 0x540000a1, 0x52800028, 0x790002a8),
                'Money kind must map to main inventory index 1')
    for offset, expected in probes.items():
        require(len(expected) == 32 and mach.raw(mach.base + offset, 32) == expected, f'Changed original code: {offset:x}')
    native = (source / 'CrimsonNative.mm').read_text()
    effects = (source / 'CrimsonEffects.h').read_text()
    inventory = (source / 'CrimsonInventory.h').read_text() + (source / 'CrimsonItemLookup.h').read_text()
    calls = {int(a, 16) for a in re.findall(r'native<[^;\n]+?>\((0x[0-9a-f]+)\)', native + effects + inventory)}
    # This diagnostic RPC is intentionally rejected on 466, before resolving it.
    if build == '466':
        require('if(buildNumber==466)return NO;' in native.split('BOOL CDSetPlayerStatRatio', 1)[1], 'Unverified diagnostic RPC reachable')
        calls.discard(0x442e5e4)
        calls.discard(0xf56b88)
    require(calls <= relocated.keys(), 'Native function without exact runtime guard')
    bindings450 = [(0x7d9004, 0x8db0f30, True), (0x3fc8bbc, 0x8f72700, True),
                                   (0x893ff0, 0x8f8ba88, False), (0x408d49c, 0x8679c28, False),
                                   (0x29eb50, 0x80cd500, False), (0x495fd98, 0x9091cfc, False)]
    bindings466 = [(0x7e5b28, 0x8dedb60, True), (0x3fcd460, 0x8fafd30, True),
                   (0x8a21e0, 0x8fc9040, False), (0x4097ac8, 0x86baf88, False),
                   (0x2a30b8, 0x810cab0, False), (0x49889f0, 0x90d0288, False)]
    if build == '466':
        globals466 = {int(key, 16): int(offset, 16) for key, offset in
                      re.findall(r'\{(0x[0-9a-f]+),(0x[0-9a-f]+)\}', header466)}
        require(globals466 == {old[1]: new[1] for old, new in zip(bindings450, bindings466)}, 'Runtime globals disagree with original callers')
    for offset, expected, load in bindings466 if build == '466' else bindings450:
        require(page_pair(mach, offset, load) == expected, 'Changed global owner/type binding')
    for offset, expected in [(0x86baf88 if build == '466' else 0x8679c28, 'N2pa18ClientTimerManagerE'),
                             (0x810cab0 if build == '466' else 0x80cd500, 'N2pa14uiCommonScript39UIGamePlayControlRootInventoryEquipmentE')]:
        rtti = mach.pointer(mach.base + offset - 8)
        require(mach.string(mach.pointer(rtti + 8)) == expected, 'Wrong native owner RTTI')
    require(profile['uuids'] == [uuid], 'Manifest/runtime identity mismatch')
    require('beginProbe' not in native and '.command.json' not in native, 'Test command handler must not ship')
    print(f'PASS: exact original identity/integrity, {len(probes)} instruction guards, {len(calls)} guarded calls, six owner/type bindings and timer/inventory RTTI. No game launched.')


if __name__ == '__main__':
    main()

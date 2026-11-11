#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build one private update candidate and run contracts. Never launch a game."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'script'))
import build

parser = argparse.ArgumentParser()
parser.add_argument('game', type=Path)
parser.add_argument('--profile', default='steam-arm64-26540391')
args = parser.parse_args()
source = ROOT / 'Modules/no-mans-sky/Sources'
config = json.loads((source.parent / 'Build.json').read_text())
manifest = json.loads((source.parent / 'Module.json').read_text())
profile = next(p for p in manifest['profiles'] if p['id'] == args.profile)
assert profile['integrityApproval'] == 'user-confirmed-steam-original'
assert profile['architecture'] == 'arm64'
out = Path('/private/tmp/trainerdock-nms-update/current')
out.mkdir(parents=True, exist_ok=True)
runtime = out / 'Trainer.dylib'
if runtime.exists() and subprocess.run(['lsof', '-t', str(runtime)], capture_output=True).stdout.strip():
    raise RuntimeError('Candidate is loaded; refusing overwrite')

# Resolve every entry in the actual original, including local/non-exported
# methods and the vtable ABI address point. No universal displacement guesses.
original = args.game / 'Contents/MacOS' / profile['executable']
symbols = {}
for line in subprocess.check_output(['xcrun', 'nm', '-arch', 'arm64', '-n', str(original)], text=True).splitlines():
    row = line.split(maxsplit=2)
    if len(row) == 3 and re.fullmatch(r'[0-9a-fA-F]+', row[0]):
        symbols[row[2]] = int(row[0], 16)
bindings = re.findall(r'\{(0x[0-9a-f]+),(0x[0-9a-f]+),"([^"]+)",(\d+)\}', (source / 'NMSBuilds.h').read_text())
assert len(bindings) == 23
keys = {int(old, 16) for old, _, _, _ in bindings}
used = re.findall(r'(?:address\(|nativeEntry\("[^"]+",)(0x[0-9a-f]+)', (source / 'NMSAdapter.m').read_text())
assert keys == {int(key, 16) for key in used}, 'Every original native binding must be mapped'
updated = profile['uuids'] == ['90ACDF11-4B80-34A5-B802-4F09782742CF']
assert updated or profile['uuids'] == ['1FABCC98-D6B6-3905-BF1B-823BD5033DA9']
for old, new, symbol, offset in bindings:
    assert symbols.get(symbol, 0) + int(offset) == int(new if updated else old, 16), symbol
print('PASS: all 23 native entries match the original arm64 symbol table.', flush=True)

objects = {}
includes = [source, ROOT / 'ModuleSDK']
paths = [*(source / n for n in config['sources'] if n != 'NMSAdapter.m'),
         *(ROOT / 'ModuleSDK' / n for n in config['sdkSources']),
         ROOT / 'ModuleSDK/MHTProtocol.m', ROOT / 'Tests/NoMansSky/CandidateChecks.m']
for path in paths:
    obj = out / (path.name + '.o')
    build.compile_object(path, obj, includes, config.get('defines', []))
    objects[path.name] = obj
build.link(list(objects.values()), runtime, True)
build.run(['codesign', '--force', '--sign', '-', '--timestamp=none', runtime])
for name, path in [('NativeContractTests', ROOT / config['nativeContractTests']),
                   ('BridgeTests', ROOT / 'Tests/BridgeTests.m'),
                   ('HiDPITests', ROOT / 'Tests/HiDPITests.m'),
                   ('IdleMaintenanceTests', ROOT / 'Tests/NoMansSky/IdleMaintenanceTests.m')]:
    obj = out / (name + '.o')
    build.compile_object(path, obj, includes, config.get('defines', []))
    chosen = [objects[n] for n in ('GameBridge.m', 'TrainerFeatures.m', 'SelectionSettings.m', 'OverlaySettings.m', 'TrainerMaterial.m', 'MHTProtocol.m')] if name == 'BridgeTests' else [o for n, o in objects.items() if n != 'Runtime.m']
    build.link([obj, *chosen], out / name)
    build.run([out / name], env=os.environ | {'MHT_PROFILE': profile['id']})

# Only the private test configuration enables the newly approved identity until
# the actual frame callback, owner, effects and input have been observed.
profile['enabled'] = True
configuration = dict(schemaVersion=1, app=dict(name='No Man’s Sky', bundleIdentifier='local.trainerdock.test.nms', version='1.0.0', build='1'), profiles=[profile])
(out / 'TrainerConfig.json').write_text(json.dumps(configuration, ensure_ascii=False, indent=2) + '\n')
profile_obj = out / 'ProfileCheck.o'
identity_obj = out / 'GameIdentity.o'
build.compile_object(ROOT / 'Tests/NoMansSky/ProfileCheck.m', profile_obj, includes)
build.compile_object(ROOT / 'Core/GameIdentity.m', identity_obj, [ROOT / 'Core'])
build.link([profile_obj, identity_obj], out / 'ProfileCheck')
build.run([out / 'ProfileCheck', args.game, out / 'TrainerConfig.json', profile['id']])
for name in ('Launch', 'Query', 'Control'):
    build.run(['xcrun', 'swiftc', '-module-cache-path', out / 'SwiftCache', '-target', 'arm64-apple-macos27.0', ROOT / 'Tests/NoMansSky' / (name + '.swift'), '-o', out / name])
print('PASS: private NMS candidate, identity, bridges, input, HiDPI and idle contracts. No game started.')

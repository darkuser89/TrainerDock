#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build one external private diagnostic candidate. Never launch or quit a game."""
from pathlib import Path
import json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
out=Path.home()/'Library/Developer/TrainerDock/StrayTest'
out.mkdir(parents=True,exist_ok=True)
data=Path('/private/tmp/trainerdock-stray');data.mkdir(exist_ok=True);data.chmod(0o700)
runtime=out/'Pending/Trainer.dylib' if '--prepare' in sys.argv else out/'Trainer.dylib'
runtime.parent.mkdir(parents=True,exist_ok=True)
if runtime.exists() and subprocess.run(['lsof','-t',str(runtime)],capture_output=True).stdout.strip():
    raise SystemExit('Loaded diagnostic library must not be overwritten.')
src=ROOT/'Modules/stray/Sources';config=json.loads((src.parent/'Build.json').read_text());includes=[src,ROOT/'ModuleSDK'];objects={}
for p in [*(src/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m']:
    o=out/(p.stem+'.o');deps=[p,*src.glob('*.h'),*src.glob('*.hpp'),*src.glob('*.inc'),ROOT/'Core/GameIdentity.m']
    if not o.exists() or o.stat().st_mtime<max(d.stat().st_mtime for d in deps):build.compile_object(p,o,includes)
    objects[p.name]=o
build.compile_object(ROOT/'Tests/Stray/Probe.mm',out/'Probe.o',includes)
build.link([*objects.values(),out/'Probe.o'],runtime,True)
build.run(['codesign','--force','--sign','-','--timestamp=none',runtime])
if any('YES' in line.split(',')[3:4] for line in (src/'TrainerFeatures.m').read_text().splitlines()):
    build.compile_object(ROOT/'Tests/BridgeTests.m',out/'BridgeTests.o',includes)
    build.link([out/'BridgeTests.o',*[objects[n] for n in ('GameBridge.m','TrainerFeatures.m','SelectionSettings.m','OverlaySettings.m','TrainerMaterial.m','MHTProtocol.m')]],out/'BridgeTests');build.run([out/'BridgeTests'])
build.compile_object(ROOT/'Tests/HiDPITests.m',out/'HiDPITests.o',includes)
build.link([out/'HiDPITests.o',*[v for k,v in objects.items() if k!='Runtime.m']],out/'HiDPITests');build.run([out/'HiDPITests'])
for name in ('CursorTests','InputLeaseTests'):
    extension='.mm' if name=='InputLeaseTests' else '.m'
    build.compile_object(ROOT/'Tests/Stray'/(name+extension),out/(name+'.o'),includes)
    build.link([out/(name+'.o')]+([objects['OverlayCursor.m']] if name=='CursorTests' else []),out/name);build.run([out/name])
for name,parts in [('PlayerLeaseTests',['PlayerEffects.mm']),('DefluxorContractTests',['Defluxor.mm']),('EnemyContractTests',['EnemyEffects.mm']),('BootstrapContractTests',['StrayEngine.mm','MemoryAccess.m'])]:
    build.compile_object(ROOT/'Tests/Stray'/(name+'.mm'),out/(name+'.o'),includes)
    build.link([out/(name+'.o'),*[objects[n] for n in parts]],out/name);build.run([out/name])
for name in ('FieldSearchTests','MetadataCacheTests'):
    build.compile_object(ROOT/'Tests/Stray'/(name+'.mm'),out/(name+'.o'),includes)
    build.link([out/(name+'.o')],out/name);build.run([out/name])
for name,p in [('GameIdentity',ROOT/'Core/GameIdentity.m'),('ProfileCheck',ROOT/'Tests/TheLongDark/ProfileCheck.m')]:
    build.compile_object(p,out/(name+'.o'),includes+[ROOT/'Core'])
build.link([out/'GameIdentity.o',out/'ProfileCheck.o'],out/'ProfileCheck')
m=json.loads((src.parent/'Module.json').read_text());m['profiles'][0]['enabled']=True
(out/'ProbeConfig.json').write_text(json.dumps(dict(schemaVersion=1,app=dict(name='Stray',bundleIdentifier='local.trainerdock.test.stray',version='1',build='1'),profiles=m['profiles'])))
for name in ('Launch','Control'):
    build.run(['xcrun','swiftc','-module-cache-path',out/'SwiftCache','-target','arm64-apple-macos27.0',ROOT/'Tests/Stray'/(name+'.swift'),'-o',out/name])
print('PASS: exact-build private candidate and synthetic display/input checks. No game started.')

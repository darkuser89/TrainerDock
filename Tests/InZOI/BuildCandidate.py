#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build the isolated full candidate and synthetic protocol/display checks. No launch."""
from pathlib import Path
import sys,json,subprocess,re
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'script'));import build
out=Path.home()/'Library/Developer/TrainerDock/InZOITest';out.mkdir(parents=True,exist_ok=True)
if (out/'Trainer.dylib').exists() and subprocess.run(['lsof','-t',str(out/'Trainer.dylib')],capture_output=True).stdout.strip():raise SystemExit('Loaded candidate must not be overwritten')
src=ROOT/'Modules/inzoi/Sources';config=json.loads((src.parent/'Build.json').read_text());includes=[src,ROOT/'ModuleSDK'];objects={}
for p in [*(src/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m']:
 o=out/(p.stem+'.o');deps=[p,*src.glob('*.h'),*src.glob('*.hpp'),ROOT/'Core/GameIdentity.m']
 if not o.exists() or o.stat().st_mtime<max(f.stat().st_mtime for f in deps):build.compile_object(p,o,includes,['IZ_PRIVATE_PROBE=1'])
 objects[p.name]=o
build.compile_object(ROOT/'Tests/InZOI/LuaProbe.mm',out/'LuaProbe.o',includes,['IZ_PRIVATE_PROBE=1'])
build.link([*objects.values(),out/'LuaProbe.o'],out/'Trainer.dylib',True,config['undefinedSymbols']);build.run(['codesign','--force','--sign','-','--timestamp=none',out/'Trainer.dylib'])
catalog_enabled=bool(re.search(r'",\s*YES,', (src/'TrainerFeatures.m').read_text()))
build.compile_object(ROOT/'Tests/InZOI/LuaSymbols.m',out/'LuaSymbols.o',[])
for name in (['BridgeTests','HiDPITests'] if catalog_enabled else ['HiDPITests']):
 build.compile_object(ROOT/'Tests'/(name+'.m'),out/(name+'.o'),includes)
 selected=[objects[n] for n in ('GameBridge.m','TrainerFeatures.m','SelectionSettings.m','OverlaySettings.m','TrainerMaterial.m','MHTProtocol.m')] if name=='BridgeTests' else [o for n,o in objects.items() if n!='Runtime.m']
 build.link([out/(name+'.o'),out/'LuaSymbols.o',*selected],out/name);build.run([out/name])
build.compile_object(ROOT/'Tests/InZOI/CursorTests.m',out/'CursorTests.o',includes)
build.link([out/'CursorTests.o',objects['OverlayCursor.m']],out/'CursorTests');build.run([out/'CursorTests'])
build.compile_object(ROOT/'Tests/InZOI/MovementTests.mm',out/'MovementTests.o',includes)
build.link([out/'MovementTests.o',objects['Movement.mm']],out/'MovementTests');build.run([out/'MovementTests'])
build.compile_object(ROOT/'Tests/InZOI/MissionDataTests.mm',out/'MissionDataTests.o',includes)
build.link([out/'MissionDataTests.o',objects['MissionData.mm']],out/'MissionDataTests');build.run([out/'MissionDataTests'])
m=json.loads((src.parent/'Module.json').read_text());m['profiles'][0]['enabled']=True;(out/'ProbeConfig.json').write_text(json.dumps(dict(schemaVersion=1,app=dict(name='inZOI',bundleIdentifier='local.trainerdock.test.inzoi',version='1',build='1'),profiles=m['profiles'])))
build.run(['xcrun','swiftc','-module-cache-path',out/'SwiftCache','-target','arm64-apple-macos27.0',ROOT/'Tests/InZOI/Launch.swift','-o',out/'Launch'])
print('PASS: private candidate, enabled-catalog bridge checks, glass and HiDPI. No game started.' if catalog_enabled else 'PASS: private candidate, glass and HiDPI; disabled-catalog bridge checks pending. No game started.')

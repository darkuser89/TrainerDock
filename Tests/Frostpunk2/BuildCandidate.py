#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build the full private candidate and meaningful synthetic checks. Never launch."""
from pathlib import Path
import json,sys,subprocess
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
OUT=Path('/private/tmp/trainerdock-frostpunk2/candidate');OUT.mkdir(exist_ok=True)
src=ROOT/'Modules/frostpunk-2/Sources'
config=json.loads((src.parent/'Build.json').read_text())
if (OUT/'Trainer.dylib').exists() and subprocess.run(['lsof','-t',str(OUT/'Trainer.dylib')],capture_output=True).stdout.strip():
 raise RuntimeError('Loaded candidate must not be overwritten')
objects={}
for p in [*(src/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m']:
 obj=OUT/(p.stem+'.o');deps=[p,*src.glob('*.h'),*src.glob('*.hpp'),ROOT/'Core/GameIdentity.m']
 if not obj.exists() or obj.stat().st_mtime<max(x.stat().st_mtime for x in deps):build.compile_object(p,obj,[src,ROOT/'ModuleSDK'])
 objects[p.name]=obj
probe=OUT/'Probe.o';build.compile_object(ROOT/'Tests/Frostpunk2/Probe.mm',probe,[src,ROOT/'ModuleSDK'],['FP_COMPLETE_CANDIDATE=1'])
build.link([*objects.values(),probe],OUT/'Trainer.dylib',True)
build.run(['codesign','--force','--sign','-','--timestamp=none',OUT/'Trainer.dylib'])
for name,path in [('BridgeTests',ROOT/'Tests/BridgeTests.m'),('HiDPITests',ROOT/'Tests/HiDPITests.m'),('NativeContractTests',ROOT/'Tests/Frostpunk2/UnrealContractTests.mm')]:
 obj=OUT/(name+'.o');build.compile_object(path,obj,[src,ROOT/'ModuleSDK'])
 selected=[objects[n] for n in ('GameBridge.m','TrainerFeatures.m','SelectionSettings.m','OverlaySettings.m','TrainerMaterial.m','MHTProtocol.m')] if name=='BridgeTests' else [o for n,o in objects.items() if n!='Runtime.m']
 build.link([obj,*selected],OUT/name);build.run([OUT/name])
# The cursor fixture supplies its own fake fp ABI and is never linked into products.
obj=OUT/'CursorContractTests.o';build.compile_object(ROOT/'Tests/Frostpunk2/CursorContractTests.mm',obj,[src,ROOT/'ModuleSDK'])
build.link([obj,objects['Cursor.mm']],OUT/'CursorContractTests');build.run([OUT/'CursorContractTests'])
obj=OUT/'SpeedContractTests.o';build.compile_object(ROOT/'Tests/Frostpunk2/SpeedContractTests.mm',obj,[src,ROOT/'ModuleSDK'])
build.link([obj,objects['Speed.mm']],OUT/'SpeedContractTests');build.run([OUT/'SpeedContractTests'])
obj=OUT/'ShortcutContractTests.o';build.compile_object(ROOT/'Tests/Frostpunk2/ShortcutContractTests.m',obj,[src,ROOT/'ModuleSDK'])
selected=[objects[n] for n in ('TrainerFeatures.m','Overlay.m','TrainerMaterial.m','OverlaySettings.m','OverlayShortcuts.m','MHTGlassIntensity.m','MHTOverlayHost.m')]
build.link([obj,*selected],OUT/'ShortcutContractTests');build.run([OUT/'ShortcutContractTests'])
obj=OUT/'ReflectionCacheTests.o';build.compile_object(ROOT/'Tests/Frostpunk2/ReflectionCacheTests.mm',obj,[src,ROOT/'ModuleSDK'])
build.link([obj],OUT/'ReflectionCacheTests');build.run([OUT/'ReflectionCacheTests'])
for name in ('ReflectionCheck.py','ThreadInputContract.py','PopulationContract.py','CommunitySelectionContract.py','OperationsContract.py','OperationsLeaseContract.py'):
 build.run([sys.executable,'-B',ROOT/'Tests/Frostpunk2'/name])
build.run([sys.executable,'-B',ROOT/'Tests/Frostpunk2/GameBindings.py','--verify-header',src/'GameBindings.h'])
for name in ('Launch','Control'):
 build.run(['xcrun','swiftc','-module-cache-path',str(OUT/'SwiftCache'),'-target','arm64-apple-macos27.0',ROOT/'Tests/Frostpunk2'/(name+'.swift'),'-o',OUT/name])
obj=OUT/'ProfileCheck.o';build.compile_object(ROOT/'Tests/Frostpunk2/ProfileCheck.m',obj,[src]);build.link([obj,objects['GameProfile.m']],OUT/'ProfileCheck')
manifest=json.loads((src.parent/'Module.json').read_text());manifest['profiles'][0]['enabled']=True
profile=dict(schemaVersion=1,app=dict(name='Frostpunk2',bundleIdentifier='local.trainerdock.test.frostpunk2',version='1',build='1'),profiles=manifest['profiles'])
(OUT/'ProbeConfig.json').write_text(json.dumps(profile))
print('PASS: complete candidate, bridge, native ABI, cursor, HiDPI and original-binding checks. No game started.')

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build one complete external candidate; never starts a game."""
from pathlib import Path
import sys,json,subprocess
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'script'));import build
source=ROOT/'Modules/terraria/Sources';config=json.loads((source.parent/'Build.json').read_text());out=Path('/private/tmp/trainerdock-terraria/next' if '--stage' in sys.argv else '/private/tmp/trainerdock-terraria');out.mkdir(exist_ok=True)
if (out/'Trainer.dylib').exists() and subprocess.run(['lsof','-t',str(out/'Trainer.dylib')],capture_output=True).stdout.strip():raise RuntimeError('Candidate loaded; refusing overwrite')
objects=[]
for p in [*(source/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m',ROOT/'Tests/Terraria/CandidateChecks.mm']:
 obj=out/('Candidate-'+p.stem+'.o');deps=[p,*source.glob('*.h'),*source.glob('*.hpp'),ROOT/'Core/GameIdentity.m']
 if not obj.exists() or obj.stat().st_mtime<max(d.stat().st_mtime for d in deps):build.compile_object(p,obj,[source,ROOT/'ModuleSDK'])
 objects.append(obj)
build.link(objects,out/'Trainer.dylib',True);build.run(['codesign','--force','--sign','-','--timestamp=none',out/'Trainer.dylib'])
for name in ('BridgeTests','HiDPITests','NativeContractTests'):
 path=ROOT/'Tests/Terraria/NativeContractTests.mm' if name=='NativeContractTests' else ROOT/'Tests'/(name+'.m');obj=out/(name+'.o');build.compile_object(path,obj,[source,ROOT/'ModuleSDK'])
 selected=[o for o in objects if o.stem.removeprefix('Candidate-') in ['GameBridge','TrainerFeatures','SelectionSettings','OverlaySettings','TrainerMaterial','MHTProtocol']] if name=='BridgeTests' else [o for o in objects if o.stem not in ('Candidate-Runtime','Candidate-CandidateChecks')]
 build.link([obj,*selected],out/name);build.run([out/name])
for name in ('Control','Query','Launch'):
 subprocess.run(['xcrun','swiftc','-module-cache-path',str(out/'SwiftCache'),'-target','arm64-apple-macos27.0',str(Path(__file__).with_name(name+'.swift')),'-o',str(out/name)],check=True)
manifest=json.loads((source.parent/'Module.json').read_text());profiles=manifest['profiles'];profiles[0]['enabled']=True
(out/'ProbeConfig.json').write_text(json.dumps(dict(schemaVersion=1,app=dict(name='Terraria',bundleIdentifier='local.trainerdock.test.terraria',version='1',build='1'),profiles=profiles)))
obj=out/'ProfileCheck.o';build.compile_object(ROOT/'Tests/Terraria/ProfileCheck.m',obj,[source]);build.link([obj,out/'Candidate-GameProfile.o'],out/'ProfileCheck');build.run([out/'ProfileCheck'])
print('Complete candidate and bridge/ABI/HiDPI tests passed. No game started.')

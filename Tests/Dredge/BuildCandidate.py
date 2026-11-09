#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build one scoped complete candidate and its tests; never starts DREDGE."""
from pathlib import Path
import argparse,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'script'));import build
parser=argparse.ArgumentParser();parser.add_argument('--stage',action='store_true');parser.add_argument('--profile',default='epic-arm64-1.5.5');parser.add_argument('--game-app',default='/Volumes/Mac Games/epic/DREDGEmKMzx/DREDGE.app');args=parser.parse_args()
source=ROOT/'Modules/dredge/Sources';config=json.loads((source.parent/'Build.json').read_text())
manifest=json.loads((source.parent/'Module.json').read_text());selected=next(p for p in manifest['profiles'] if p['id']==args.profile);architecture=selected.get('architecture','arm64')
def compile_object(*a,**kw):return build.compile_object(*a,**kw,architecture=architecture)
def link(*a,**kw):return build.link(*a,**kw,architecture=architecture)
out=Path('/private/tmp/trainerdock-dredge/next' if args.stage else '/private/tmp/trainerdock-dredge');out.mkdir(exist_ok=True)
runtime=out/'Trainer.dylib'
if runtime.exists() and subprocess.run(['lsof','-t',str(runtime)],capture_output=True).stdout.strip():raise RuntimeError('Candidate is loaded; refusing overwrite')
objects={}
for path in [*(source/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m',ROOT/'Tests/Dredge/CandidateChecks.mm']:
 obj=out/('Candidate-'+architecture+'-'+path.name+'.o');deps=[path,*source.glob('*.h'),*source.glob('*.hpp'),ROOT/'Core/GameIdentity.m',ROOT/'Core/GameIdentity.h']
 if not obj.exists() or obj.stat().st_mtime<max(p.stat().st_mtime for p in deps):compile_object(path,obj,[source,ROOT/'ModuleSDK'])
 objects[path.name]=obj
link(list(objects.values()),runtime,True);build.run(['codesign','--force','--sign','-','--timestamp=none',runtime])
for name in ('BridgeTests','HiDPITests'):
 obj=out/(name+'.o');compile_object(ROOT/'Tests'/(name+'.m'),obj,[source,ROOT/'ModuleSDK'])
 chosen=[objects[n] for n in ['GameBridge.m','TrainerFeatures.m','SelectionSettings.m','OverlaySettings.m','TrainerMaterial.m','MHTProtocol.m']] if name=='BridgeTests' else [obj for name,obj in objects.items() if name not in ('Runtime.m','CandidateChecks.mm')]
 link([obj,*chosen],out/name);build.run([out/name])
if config.get('nativeContractTests'):
 obj=out/'NativeContractTests.o';compile_object(ROOT/config['nativeContractTests'],obj,[source,ROOT/'ModuleSDK'])
 link([obj,*[o for n,o in objects.items() if n not in ('Runtime.m','CandidateChecks.mm')]],out/'NativeContractTests');build.run([out/'NativeContractTests'])
profiles=manifest['profiles'];selected['enabled']=True
(out/'LaunchInput.json').write_text(json.dumps(dict(profile=args.profile,gameApp=args.game_app)))
(out/'ProbeConfig.json').write_text(json.dumps(dict(schemaVersion=1,app=dict(name='DREDGE',bundleIdentifier='local.trainerdock.test.dredge',version='0.1.0',build='1'),profiles=profiles)))
obj=out/'ProfileCheck.o';compile_object(ROOT/'Tests/Dredge/ProfileCheck.m',obj,[ROOT/'Core']);link([obj,objects['GameProfile.m']],out/'ProfileCheck')
build.run([out/'ProfileCheck',out/'ProbeConfig.json',args.profile,args.game_app])
for name in ('Control','Query'):
 subprocess.run(['xcrun','swiftc','-module-cache-path',str(out/'SwiftCache'),'-target','arm64-apple-macos27.0',str(Path(__file__).with_name(name+'.swift')),'-o',str(out/name)],check=True)
for path in [ROOT/'Tests/Dredge/Launch.m',ROOT/'Core/MHTEpicLaunch.m']:
 obj=out/(path.stem+'.o');compile_object(path,obj,[ROOT/'Core']);objects[path.name]=obj
link([objects['Launch.m'],objects['MHTEpicLaunch.m'],objects['GameProfile.m']],out/'Launch')
print('Complete DREDGE candidate, identity, bridge, native and HiDPI checks passed. No game started.')

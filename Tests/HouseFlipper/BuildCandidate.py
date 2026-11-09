#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build a private HouseFlipper candidate and real contract tests; never launch a game."""
from pathlib import Path
import argparse,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
parser=argparse.ArgumentParser();parser.add_argument('--stage',action='store_true');args=parser.parse_args()
source=ROOT/'Modules/house-flipper/Sources'
config=json.loads((source.parent/'Build.json').read_text())
manifest=json.loads((source.parent/'Module.json').read_text())
profile=manifest['profiles'][0]
assert profile['integrityApproval']=='user-confirmed-steam-original'
out=Path('/private/tmp/trainerdock-house-flipper')/('next' if args.stage else 'current')
out.mkdir(parents=True,exist_ok=True)
runtime=out/'Trainer.dylib'
architecture='x86_64'
if runtime.exists() and subprocess.run(['lsof','-t',str(runtime)],capture_output=True).stdout.strip():
 raise RuntimeError('Candidate is loaded; refusing overwrite')
objects={};includes=[source,ROOT/'ModuleSDK']
for path in [*(source/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m',ROOT/'Tests/HouseFlipper/Probe.mm']:
 obj=out/(path.name+'.o')
 build.compile_object(path,obj,includes,config.get('defines',[]),architecture=architecture);objects[path.name]=obj
build.link(list(objects.values()),runtime,True,architecture=architecture)
build.run(['codesign','--force','--sign','-','--timestamp=none',runtime])
for name,path in [('NativeContractTests',ROOT/config['nativeContractTests']),('BridgeTests',ROOT/'Tests/BridgeTests.m'),('HiDPITests',ROOT/'Tests/HiDPITests.m')]:
 obj=out/(name+'.o');build.compile_object(path,obj,includes,config.get('defines',[]),architecture=architecture)
 chosen=[objects[n] for n in ('GameBridge.m','TrainerFeatures.m','SelectionSettings.m','OverlaySettings.m','TrainerMaterial.m','MHTProtocol.m')] if name=='BridgeTests' else [o for n,o in objects.items() if n not in ('Runtime.m','Probe.mm')]
 build.link([obj,*chosen],out/name,architecture=architecture)
 build.run([out/name],env=__import__('os').environ|{'MHT_PROFILE':profile['id']})
obj=out/'EffectsContractTests.o'
build.compile_object(ROOT/'Tests/HouseFlipper/EffectsContractTests.mm',obj,includes,config.get('defines',[]),architecture=architecture)
build.link([obj],out/'EffectsContractTests',architecture=architecture);build.run([out/'EffectsContractTests'])
# A test-only in-memory/profile copy enables this exact approved identity for the
# initial observation. The source product remains disabled until proven in game.
profile['enabled']=True
(out/'TrainerConfig.json').write_text(json.dumps(dict(schemaVersion=1,app=dict(name='HouseFlipper',bundleIdentifier='local.trainerdock.test.house-flipper',version='0.1.0',build='1'),profiles=[profile])))
obj=out/'ProfileCheck.o';build.compile_object(ROOT/'Tests/HouseFlipper/ProfileCheck.m',obj,[source,ROOT/'Core'],architecture=architecture)
build.link([obj,objects['GameProfile.m']],out/'ProfileCheck',architecture=architecture)
build.run([out/'ProfileCheck','/Volumes/Mac Games/SteamLibrary/steamapps/common/House Flipper/HouseFlipper.app',out/'TrainerConfig.json'])
for name in ('Launch','Query'):
 build.run(['xcrun','swiftc','-module-cache-path',out/'SwiftCache','-target','arm64-apple-macos27.0',ROOT/'Tests/HouseFlipper'/(name+'.swift'),'-o',out/name])
print('HouseFlipper candidate, identity, contracts and HiDPI checks passed; no game started.')

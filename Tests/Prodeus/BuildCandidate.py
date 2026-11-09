#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build a private Prodeus candidate and real contract tests; never launch a game."""
from pathlib import Path
import argparse,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
parser=argparse.ArgumentParser();parser.add_argument('--stage',action='store_true');args=parser.parse_args()
source=ROOT/'Modules/prodeus/Sources'
config=json.loads((source.parent/'Build.json').read_text())
manifest=json.loads((source.parent/'Module.json').read_text())
profile=manifest['profiles'][0]
assert profile['integrityApproval']=='user-confirmed-steam-original'
out=Path('/private/tmp/trainerdock-prodeus')/('next' if args.stage else 'current')
out.mkdir(parents=True,exist_ok=True)
runtime=out/'Trainer.dylib'
if runtime.exists() and subprocess.run(['lsof','-t',str(runtime)],capture_output=True).stdout.strip():
 raise RuntimeError('Candidate is loaded; refusing overwrite')
objects={};includes=[source,ROOT/'ModuleSDK']
for path in [*(source/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m',ROOT/'Tests/Prodeus/Probe.mm']:
 obj=out/(path.name+'.o')
 build.compile_object(path,obj,includes,config.get('defines',[]));objects[path.name]=obj
build.link(list(objects.values()),runtime,True)
build.run(['codesign','--force','--sign','-','--timestamp=none',runtime])
for name,path in [('NativeContractTests',ROOT/config['nativeContractTests']),('HiDPITests',ROOT/'Tests/HiDPITests.m')]:
 obj=out/(name+'.o');build.compile_object(path,obj,includes,config.get('defines',[]))
 build.link([obj,*[o for n,o in objects.items() if n not in ('Runtime.m','Probe.mm')]],out/name)
 build.run([out/name],env=__import__('os').environ|{'MHT_PROFILE':profile['id']})
obj=out/'EffectsContractTests.o'
build.compile_object(ROOT/'Tests/Prodeus/EffectsContractTests.mm',obj,includes,config.get('defines',[]))
build.link([obj],out/'EffectsContractTests');build.run([out/'EffectsContractTests'])
# A test-only in-memory/profile copy enables this exact approved identity for the
# initial observation. The source product remains disabled until proven in game.
profile['enabled']=True
(out/'TrainerConfig.json').write_text(json.dumps(dict(schemaVersion=1,app=dict(name='Prodeus',bundleIdentifier='local.trainerdock.test.prodeus',version='0.1.0',build='1'),profiles=[profile])))
obj=out/'ProfileCheck.o';build.compile_object(ROOT/'Tests/Prodeus/ProfileCheck.m',obj,[source,ROOT/'Core'])
build.link([obj,objects['GameProfile.m']],out/'ProfileCheck')
build.run([out/'ProfileCheck','/Volumes/Mac Games/SteamLibrary/steamapps/common/Prodeus/Prodeus.app',out/'TrainerConfig.json'])
for name in ('Launch','Query'):
 build.run(['xcrun','swiftc','-module-cache-path',out/'SwiftCache','-target','arm64-apple-macos27.0',ROOT/'Tests/Prodeus'/(name+'.swift'),'-o',out/name])
print('Prodeus candidate, identity, contracts and HiDPI checks passed; no game started.')

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build a private exact-build candidate and contracts; never launch or stop games."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--stage',action='store_true',help='Prepare the one short-lived exchange candidate without touching loaded libraries')
    args=parser.parse_args()
    source=ROOT/'Modules/frostpunk/Sources'
    config=json.loads((source.parent/'Build.json').read_text())
    manifest=json.loads((source.parent/'Module.json').read_text())
    profile=manifest['profiles'][0]
    assert profile['id']=='steam-x86_64-15262773'
    assert profile['integrityApproval']=='user-confirmed-steam-original'
    out=Path.home()/'Library/Developer/TrainerDock/Tests/Frostpunk'
    if args.stage: out=out/'Exchange'
    out.mkdir(parents=True,exist_ok=True)
    runtime=out/'Trainer.dylib'
    if runtime.exists() and subprocess.run(['lsof','-t',str(runtime)],capture_output=True).stdout.strip():
        raise RuntimeError('Candidate is loaded; end its test normally before replacing it')
    objects={}
    includes=[source,ROOT/'ModuleSDK']
    architecture='x86_64'
    for path in [*(source/name for name in config['sources']),
                 *(ROOT/'ModuleSDK'/name for name in config['sdkSources']),
                 ROOT/'ModuleSDK/MHTProtocol.m']:
        obj=out/(path.name+'.o')
        build.compile_object(path,obj,includes,config.get('defines',[]),architecture=architecture)
        objects[path.name]=obj
    build.link(list(objects.values()),runtime,True,config.get('undefinedSymbols',[]),architecture=architecture)
    build.run(['codesign','--force','--sign','-','--timestamp=none',runtime])
    support=[]
    for name in config.get('testSupportSources',[]):
        path=ROOT/name
        assert ROOT/'Tests' in path.resolve().parents
        obj=out/('Support-'+path.name+'.o')
        build.compile_object(path,obj,includes,config.get('defines',[]),architecture=architecture)
        support.append(obj)
    for name,path in [('NativeContractTests',ROOT/'Tests/Frostpunk/NativeContractTests.m'),
                      ('BridgeTests',ROOT/'Tests/BridgeTests.m'),
                      ('HiDPITests',ROOT/'Tests/HiDPITests.m')]:
        obj=out/(name+'.o')
        build.compile_object(path,obj,includes,config.get('defines',[]),architecture=architecture)
        chosen=[objects[n] for n in ('GameBridge.m','TrainerFeatures.m','SelectionSettings.m',
                  'OverlaySettings.m','TrainerMaterial.m','MHTProtocol.m')] if name=='BridgeTests' else [o for n,o in objects.items() if n!='Runtime.m']
        build.link([obj,*chosen,*support],out/name,architecture=architecture)
        build.run([out/name],env=os.environ|{'MHT_PROFILE':profile['id']})
    # Only this private test configuration enables the approved original build;
    # product development/profile gates remain unchanged until in-game evidence.
    profile['enabled']=True
    (out/'TrainerConfig.json').write_text(json.dumps(dict(schemaVersion=1,
        app=dict(name='Frostpunk',bundleIdentifier='local.trainerdock.test.frostpunk',
                 version=manifest['version'],build='1'),profiles=[profile])))
    obj=out/'ProfileCheck.o'
    build.compile_object(ROOT/'Tests/Frostpunk/ProfileCheck.m',obj,[source,ROOT/'Core'],architecture=architecture)
    build.link([obj,objects['GameProfile.m']],out/'ProfileCheck',architecture=architecture)
    build.run([out/'ProfileCheck',args.game,out/'TrainerConfig.json'])
    build.run(['xcrun','swiftc','-module-cache-path',out/'SwiftCache','-target','arm64-apple-macos27.0',
               ROOT/'Tests/Frostpunk/Launch.swift','-o',out/'Launch'])
    print('Private Frostpunk candidate and contracts checked; no game launched.')

if __name__=='__main__':
    main()

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Explicit temporary development build; no product installation or game launch."""
from pathlib import Path
import json,sys,os,subprocess
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
from build import compile_object,link,run
from managed import compile_managed
root=Path('/private/tmp/mht-vampire-survivors');stage=root/'Build';stage.mkdir(parents=True,exist_ok=True)
if (root/'Candidate.dylib').exists() and subprocess.run(['lsof','-t',str(root/'Candidate.dylib')],capture_output=True).stdout.strip():raise SystemExit('Loaded candidate: end game normally before replacing it.')
source=ROOT/'Modules/vampire-survivors/Sources';sdk=ROOT/'ModuleSDK';module=source.parent
manifest=json.loads((module/'Module.json').read_text());config=json.loads((module/'Build.json').read_text())
compile_managed(module,manifest,config,stage)
objects=[];testobjects=[]
for name in config['sources']:
 obj=stage/(name+'.o');compile_object(source/name,obj,[source,sdk,stage]);objects.append(obj)
 if name!='Runtime.m':testobjects.append(obj)
for name in ['MHTProtocol.m',*config['sdkSources']]:
 obj=stage/(name+'.o');compile_object(sdk/name,obj,[source,sdk,stage]);objects.append(obj);testobjects.append(obj)
link(objects,root/'Candidate.dylib',True);run(['codesign','-s','-','--timestamp=none',root/'Candidate.dylib'])
for file in ['Tests/VampireSurvivors/NativeContractTests.m','Tests/BridgeTests.m','Tests/HiDPITests.m']:
 obj=stage/(Path(file).stem+'.o');compile_object(ROOT/file,obj,[source,sdk,stage]);out=stage/Path(file).stem;selected=[stage/(n+'.o') for n in ['MHTProtocol.m','GameBridge.m','TrainerFeatures.m','SelectionSettings.m','OverlaySettings.m','TrainerMaterial.m']] if Path(file).name=='BridgeTests.m' else testobjects;link([obj,*selected],out);run([out])
print('Development candidate and synthetic tests passed; no game started.')

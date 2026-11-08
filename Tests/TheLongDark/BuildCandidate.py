#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build a complete temporary candidate; no product installation/game start."""
from pathlib import Path
import json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
source=ROOT/'Modules/the-long-dark/Sources';config=json.loads((source.parent/'Build.json').read_text())
output=Path('/private/tmp/trainerdock-the-long-dark/next' if '--stage' in sys.argv else '/private/tmp/trainerdock-the-long-dark');output.mkdir(exist_ok=True);objects=[]
if (output/'Trainer.dylib').exists() and subprocess.run(['lsof','-t',str(output/'Trainer.dylib')],capture_output=True).stdout.strip():raise RuntimeError('Candidate is loaded; refusing overwrite')
for path in [*(source/n for n in config['sources']),*(ROOT/'ModuleSDK'/n for n in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m',ROOT/'Tests/TheLongDark/CandidateChecks.mm']:
 obj=output/('Candidate-'+path.stem+'.o')
 dependencies=[path,*source.glob('*.h'),*source.glob('*.hpp'),*(ROOT/'ModuleSDK').glob('*.h')]
 if not obj.exists() or obj.stat().st_mtime<max(p.stat().st_mtime for p in dependencies):build.compile_object(path,obj,[source,ROOT/'ModuleSDK'],config.get('defines',[]))
 objects.append(obj)
build.link(objects,output/'Trainer.dylib',True)
build.run(['codesign','--force','--sign','-','--timestamp=none',output/'Trainer.dylib'])
for name in ('BridgeTests','HiDPITests','NativeContractTests'):
 obj=output/(name+'.o');build.compile_object(ROOT/'Tests/TheLongDark/NativeContractTests.mm' if name=='NativeContractTests' else ROOT/'Tests'/(name+'.m'),obj,[source,ROOT/'ModuleSDK'])
 excludes=['Runtime','CandidateChecks']
 if name=='BridgeTests':
  names=['GameBridge','TrainerFeatures','SelectionSettings','OverlaySettings','TrainerMaterial','MHTProtocol'];selected=[o for o in objects if o.stem.removeprefix('Candidate-') in names]
 else:selected=[o for o in objects if o.stem.removeprefix('Candidate-') not in excludes]
 exe=output/name;build.link([obj,*selected],exe);build.run([exe])
for name in ('Control','Launch','Query'):
 subprocess.run(['xcrun','swiftc','-module-cache-path',str(output/'SwiftCache'),'-target','arm64-apple-macos27.0',str(Path(__file__).with_name(name+'.swift')),'-o',str(output/name)],check=True)
print('Complete candidate built and synthetically checked. No game launched.')

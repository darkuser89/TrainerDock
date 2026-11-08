#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build an explicitly temporary in-game test candidate; never install a product."""
from pathlib import Path
import json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
source=ROOT/'Modules/death-stranding/Sources';config=json.loads((source.parent/'Build.json').read_text())
output=Path('/private/tmp/trainerdock-death-stranding/Candidate.next' if '--stage' in sys.argv else '/private/tmp/trainerdock-death-stranding/Candidate');output.mkdir(exist_ok=True)
if (output/'Trainer.dylib').exists() and subprocess.run(['lsof','-t',str(output/'Trainer.dylib')],capture_output=True).stdout.strip():raise RuntimeError('Candidate is loaded; refuse to overwrite')
includes=[source,ROOT/'ModuleSDK'];objects=[]
for path in [*(source/name for name in config['sources']),*(ROOT/'ModuleSDK'/name for name in config['sdkSources']),ROOT/'ModuleSDK/MHTProtocol.m',ROOT/'Tests/DeathStranding/CandidateProbe.m']:
    obj=output/(path.stem+'.o');build.compile_object(path,obj,includes);objects.append(obj)
build.link(objects,output/'Trainer.dylib',True)
build.run(['codesign','--force','--sign','-','--timestamp=none',output/'Trainer.dylib'])
test_object=output/'NativeContractTests.o'
build.compile_object(ROOT/'Tests/DeathStranding/NativeContractTests.m',test_object,includes)
test_objects=[obj for obj in objects if obj.stem not in ('Runtime','CandidateProbe')]
test_exe=output/'NativeContractTests';build.link([test_object,*test_objects],test_exe);build.run([test_exe])
test_object=output/'HiDPITests.o';build.compile_object(ROOT/'Tests/HiDPITests.m',test_object,includes)
test_exe=output/'HiDPITests';build.link([test_object,*test_objects],test_exe);build.run([test_exe])
print('Built temporary native test candidate, no product installed or game started.')

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
from pathlib import Path
import sys,json,os
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
from build import compile_object,link,run
scratch=Path('/private/tmp/mht-control')
state=scratch/'ModuleState.json'
if state.exists():
 try:
  pid=json.loads(state.read_text()).get('pid')
  if isinstance(pid,int) and pid>1:
   try:os.kill(pid,0)
   except ProcessLookupError:pass
   else:raise SystemExit('Control-Prüfinstanz läuft noch; geladene Bibliothek nicht überschreiben.')
 except PermissionError:raise SystemExit('Prozessende nicht nachweisbar; geladene Bibliothek bleibt geschützt.')
stage=scratch/'ModuleBuild';stage.mkdir(parents=True,exist_ok=True)
source=ROOT/'Modules/control/Sources';sdk=ROOT/'ModuleSDK';objects=[]
config=json.loads((source.parent/'Build.json').read_text())
for name in config['sources']:
 if name=='Runtime.m':continue
 obj=stage/(name+'.o');compile_object(source/name,obj,[source,sdk,ROOT/'Tests/Control'],["MHT_CONTROL_TESTING=1"]);objects.append(obj)
for name in ['MHTProtocol.m',*config['sdkSources']]:
 obj=stage/(name+'.o');compile_object(sdk/name,obj,[source,sdk]);objects.append(obj)
for name in ['ModuleProbe.mm','NativeDiagnostics.mm']:
 obj=stage/(name+'.o');compile_object(ROOT/'Tests/Control'/name,obj,[source,sdk,ROOT/'Tests/Control'],["MHT_CONTROL_TESTING=1"]);objects.append(obj)
out=stage.parent/'Candidate-Direct.dylib';link(objects,out,True);run(['codesign','-s','-',out])
print(out)

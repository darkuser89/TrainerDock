#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Explicit, session-scoped live checks. Never starts or closes a game.

Run only in an authorized, paused local test city. No save files are accessed.
The native readback is authoritative; transport acknowledgement is not success.
"""
import json,math,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=Path('/private/tmp/trainerdock-frostpunk2')

def query(action):
 p=subprocess.run([sys.executable,'-B',ROOT/'Tests/Frostpunk2/Query.py',json.dumps(action)],capture_output=True,text=True,check=True)
 return json.loads(p.stdout)['result']

def command(action):
 p=subprocess.run([OUT/'Control',action],capture_output=True,text=True,check=True)
 d=json.loads(p.stdout)
 if d.get('error'):raise RuntimeError(d['error'])
 return d['state']

def values():
 d=query({'op':'values'})
 if not d.get('ready'):raise RuntimeError(d.get('note','No confirmed city'))
 return d

def amount(feature):
 row=next(r for r in values()['values'] if r['feature']==feature)
 if not row.get('available'):raise RuntimeError(str(row))
 return row['value']

def set_value(feature,target):
 command(f'value:{feature}:{target}')
 s=command(f'run:{feature}')
 actual=amount(feature)
 if actual!=target:
  # The integration message is emitted only after immediate native readback.
  # Later consumption/clamping is distinct from an Edit action's confirmation.
  expected=f'Nativ gesetzt und zurückgelesen: {target:.0f}'
  if s.get('message')!=expected:raise RuntimeError(f'Feature {feature}: expected {target}, read {actual}; {s.get("message")}')
  print(f'Native edit {feature} confirmed {target}; later engine value {actual}',flush=True)
 return target

mode=sys.argv[1] if len(sys.argv)>1 else 'read'
if mode=='read':print(json.dumps(values(),ensure_ascii=False,indent=2));raise SystemExit
if mode not in ('resources','statistics','flags'):raise SystemExit('Mode must be read/resources/statistics/flags')
results=[]
if mode in ('resources','statistics'):
 for feature in (range(9) if mode=='resources' else range(20,26)):
  before=amount(feature)
  if not math.isfinite(before):raise RuntimeError('Finite baseline required')
  if before!=int(before):
   print(f'SKIP {feature}: float baseline {before}; original setter only restores integers',flush=True)
   results.append(dict(feature=feature,notExecuted=True,reason='Fractional original baseline cannot be restored through the int32 native setter',before=before))
   continue
  target=before-1 if before>0 else 1
  attempted=False
  try:
   attempted=True
   changed=set_value(feature,target)
  finally:
   if attempted:
    restored=set_value(feature,before)
    command(f'value:{feature}:{0 if mode=="statistics" else 10000}')
  results.append(dict(feature=feature,before=before,changed=changed,restored=restored))
  print(f'PASS {feature}: {before} -> {changed} -> {restored}',flush=True)
else:
 for feature in (9,11,12,13,15,16,18,19):
  initial=command('state')['features'][feature]
  if initial['wanted']:raise RuntimeError(f'Feature {feature} already requested; preserve user state')
  try:
   s=command(f'set:{feature}:1')['features'][feature]
   if not s.get('active'):raise RuntimeError(f'Feature {feature}: {s.get("note")}')
  finally:
   off=command(f'set:{feature}:0')['features'][feature]
  if off.get('active') or off.get('wanted'):raise RuntimeError(f'Feature {feature}: off not confirmed')
  results.append(dict(feature=feature,nativeActiveReadback=True,note=s.get('note'),off=off.get('note')))
  print(f'PASS native lease {feature}: on/readback/off; {s.get("note")}',flush=True)
(OUT/(mode+'-checks.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2))

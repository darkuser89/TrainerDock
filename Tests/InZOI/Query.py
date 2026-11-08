#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Private session-scoped diagnostics; never start or close a game."""
from pathlib import Path
import json,uuid,time,sys,os
ROOT=Path('/private/tmp/trainerdock-inzoi')
def query(action):
 session=json.loads((ROOT/'Session.json').read_text());os.kill(session['pid'],0)
 identifier=str(uuid.uuid4());path=ROOT/'Request.json';path.write_text(json.dumps(dict(id=identifier,token=session['token'],action=action)));path.chmod(0o600)
 deadline=time.monotonic()+30
 while time.monotonic()<deadline:
  try:
   reply=json.loads((ROOT/'Reply.json').read_text())
   if reply.get('id')==identifier:
    if 'error' in reply:raise RuntimeError(reply['error'])
    return reply['result']
  except (FileNotFoundError,json.JSONDecodeError):pass
  time.sleep(.05)
 raise RuntimeError('No scoped native reply; no replacement start attempted.')
def memory(address,length):return bytes.fromhex(query(dict(op='read',address=hex(address),length=length))['hex'])
if __name__=='__main__':print(json.dumps(query(json.loads(sys.argv[1]) if len(sys.argv)>1 else dict(op='status')),ensure_ascii=False,indent=2))

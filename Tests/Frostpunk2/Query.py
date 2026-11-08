#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Private local diagnostic request. Never starts or closes a game."""
from pathlib import Path
import json,uuid,time,sys,os
root=Path('/private/tmp/trainerdock-frostpunk2')
session=json.loads((root/'Session.json').read_text());os.kill(session['pid'],0)
action=json.loads(sys.argv[1]) if len(sys.argv)>1 else {'op':'status'}
identifier=str(uuid.uuid4());path=root/'Request.json';path.write_text(json.dumps(dict(id=identifier,token=session['token'],action=action)));path.chmod(0o600)
deadline=time.monotonic()+30
while time.monotonic()<deadline:
 try:
  reply=json.loads((root/'Reply.json').read_text())
  if reply.get('id')==identifier:
   print(json.dumps(reply,ensure_ascii=False,indent=2));sys.exit(1 if 'error' in reply else 0)
 except (FileNotFoundError,json.JSONDecodeError):pass
 time.sleep(.1)
raise SystemExit('No scoped native probe reply; no replacement start attempted.')

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Client for the original game's existing loopback diagnostic API."""
import json,urllib.request,sys
from pathlib import Path
URL='http://127.0.0.1:11212/mcp'
def call(name,arguments=None):
 req=urllib.request.Request(URL,data=json.dumps(dict(jsonrpc='2.0',id=1,method='tools/call',params=dict(name=name,arguments=arguments or {}))).encode(),headers={'Content-Type':'application/json','Accept':'application/json'})
 reply=json.load(urllib.request.urlopen(req,timeout=15))
 if 'error' in reply:raise RuntimeError(reply['error'])
 r=reply['result']
 if r.get('isError'):raise RuntimeError(r)
 return r
if __name__=='__main__':print(json.dumps(call(sys.argv[1],json.loads(sys.argv[2]) if len(sys.argv)>2 else {}),ensure_ascii=False,indent=2))

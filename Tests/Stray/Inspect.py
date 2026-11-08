#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Bounded read-only inspection of the exact Stray original; never executes it."""
from pathlib import Path
import argparse,importlib.util,re,struct
spec=importlib.util.spec_from_file_location('trainerdock_original_image',Path(__file__).resolve().parents[1]/'Frostpunk2/Inspect.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
IMAGE=Path('/Volumes/Mac Games/SteamLibrary/steamapps/common/Stray/Stray.app/Contents/MacOS/Stray-Mac-Shipping')
class Image(module.Image):
 def __init__(self,path=IMAGE):super().__init__(path)
 def symbols(self,pattern):
  seen=set();at=32;count=struct.unpack_from('<I',self.data,16)[0]
  for _ in range(count):
   cmd,size=struct.unpack_from('<II',self.data,at)
   if cmd==2:
    offset,count,strings,length=struct.unpack_from('<IIII',self.data,at+8)
    assert offset+count*16<=len(self.data) and strings+length<=len(self.data)
    for i in range(count):
     strx,kind,sect,desc,value=struct.unpack_from('<IBBHQ',self.data,offset+i*16)
     if not strx or strx>=length:continue
     start=strings+strx;end=self.data.find(b'\0',start,strings+length)
     if end<start:continue
     name=self.data[start:end].decode('utf8',errors='replace')
     if value and (value,name) not in seen and re.search(pattern,name,re.I):
      seen.add((value,name));yield value,name
   at+=size
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['names','regs','dis','refs','symbols']);p.add_argument('value');p.add_argument('--size',type=int,default=192);p.add_argument('--limit',type=int,default=100);a=p.parse_args();m=Image()
 if a.action=='dis':m.dis(int(a.value,0),a.size)
 elif a.action=='refs':print([hex(x) for x in m.refs(int(a.value,0))][:a.limit])
 elif a.action=='regs':m.registrations(a.value)
 else:
  for i,(va,name) in enumerate(m.symbols(a.value) if a.action=='symbols' else m.names(a.value)):
   if i>=a.limit:print('Additional matches omitted');break
   print(hex(va),name)

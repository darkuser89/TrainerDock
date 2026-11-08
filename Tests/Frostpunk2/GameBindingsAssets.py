#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read original unencrypted Pak v11 directory indexes; extract no game files."""
import argparse, hashlib, json, struct
from pathlib import Path
from Inspect import IMAGE
PAKS=IMAGE.parent.parent/'UE/Frostpunk2/Content/Paks'
LIMIT=32*1024*1024
class Reader:
 def __init__(self,data):self.data=data;self.at=0
 def take(self,n):
  if n<0 or self.at+n>len(self.data):raise ValueError('Index bounds')
  value=self.data[self.at:self.at+n];self.at+=n;return value
 def u32(self):return struct.unpack('<I',self.take(4))[0]
 def string(self):
  n=self.u32()
  if n>4096:raise ValueError('Unexpected FString')
  value=self.take(n)
  if not value.endswith(b'\0'):raise ValueError('Unterminated FString')
  return value[:-1].decode('utf8')
def paths(pak):
 with pak.open('rb') as f:
  f.seek(-4096,2);tail=f.read();i=tail.rfind(bytes.fromhex('e1126f5a'))
  if i<17 or tail[i-1]!=0:raise ValueError('Unknown or encrypted Pak')
  magic,version,off,size=struct.unpack_from('<IIQQ',tail,i)
  if version!=11 or not 0<size<=LIMIT:raise ValueError('Unsupported Pak index')
  f.seek(off);data=f.read(size)
  if hashlib.sha1(data).digest()!=tail[i+24:i+44]:raise ValueError('Main index SHA1 mismatch')
  r=Reader(data);mount=r.string();entries=r.u32();r.take(8)
  if r.u32():r.take(36)
  if not r.u32():raise ValueError('Full directory index absent')
  off,size=struct.unpack('<QQ',r.take(16));digest=r.take(20)
  if not 0<size<=LIMIT:raise ValueError('Directory index limit')
  f.seek(off);data=f.read(size)
  if hashlib.sha1(data).digest()!=digest:raise ValueError('Directory index SHA1 mismatch')
  r=Reader(data);directories=r.u32()
  if directories>entries*2:raise ValueError('Directory count')
  for _ in range(directories):
   directory=r.string();count=r.u32()
   if count>entries:raise ValueError('File count')
   for _ in range(count):
    filename=r.string();location=r.u32();full=mount+directory+filename
    prefix='../../../Frostpunk2/Content/'
    if full.startswith(prefix):full='/Game/'+full[len(prefix):]
    yield full,location
  if r.at!=len(data):raise ValueError('Trailing directory data')
def uncompressed_strings(pak, location):
 """Return text from a small original entry; never decompress, load, or extract."""
 import re
 with pak.open('rb') as f:
  f.seek(-4096,2);tail=f.read();i=tail.rfind(bytes.fromhex('e1126f5a'))
  off,size=struct.unpack_from('<QQ',tail,i+8);f.seek(off);r=Reader(f.read(size))
  r.string();r.u32();r.take(8)
  if r.u32():r.take(36)
  if r.u32():r.take(36)
  entries=r.take(r.u32());r=Reader(entries);r.at=location;flags=r.u32()
  if flags>>23&0x3f: return []
  off=struct.unpack('<I' if flags>>31 else '<Q',r.take(4 if flags>>31 else 8))[0]
  size=struct.unpack('<I' if flags>>30&1 else '<Q',r.take(4 if flags>>30&1 else 8))[0]
  if size>1024*1024:raise ValueError('Original text entry too large')
  f.seek(off);header=f.read(53)
  _,compressed,uncompressed,method=struct.unpack_from('<QQQI',header)
  if method or compressed!=size or uncompressed!=size or header[48]:raise ValueError('Unexpected entry header')
  data=f.read(size)
  if hashlib.sha1(data).digest()!=header[28:48]:raise ValueError('Original entry SHA1 mismatch')
  return [x.decode('ascii') for x in re.findall(rb'[\x20-\x7e]{5,}',data)]

if __name__=='__main__':
 import re
 p=argparse.ArgumentParser();p.add_argument('--pattern',default=r'Configs/(?:Resources/Types|Statistics(?:/Types)?)/.*\.uasset$');p.add_argument('--strings',action='store_true');a=p.parse_args()
 for pak in sorted(PAKS.glob('*.pak')):
  for path,location in paths(pak):
   if re.search(a.pattern,path,re.I):
    row={'pak':pak.name,'asset':path,'encodedEntry':location}
    if a.strings:row['originalASCII']=uncompressed_strings(pak,location)
    print(json.dumps(row))

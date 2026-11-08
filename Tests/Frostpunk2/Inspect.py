#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only bounded analysis of the user's original arm64 Mach-O, no execution."""
from pathlib import Path
import struct,re,argparse
from capstone import Cs,CS_ARCH_ARM64,CS_MODE_ARM
IMAGE=Path('/Volumes/Mac Games/SteamLibrary/steamapps/common/Frostpunk2/Frostpunk2.app/Contents/MacOS/Frostpunk2')
class Image:
 def __init__(self,path=IMAGE):
  self.data=path.read_bytes();h=struct.unpack_from('<8I',self.data);assert h[0]==0xfeedfacf and h[1]==0x100000c;self.segments=[];self.sections=[];self.starts=[];at=32
  for _ in range(h[4]):
   cmd,size=struct.unpack_from('<II',self.data,at)
   if cmd==0x19:
    name,va,vs,off,fs=struct.unpack_from('<16sQQQQ',self.data,at+8);self.segments.append((name.rstrip(b"\0").decode(),va,vs,off,fs))
    ns=struct.unpack_from('<I',self.data,at+64)[0]
    for i in range(ns):
     x=at+72+i*80;name,seg,addr,siz,off=struct.unpack_from('<16s16sQQI',self.data,x);self.sections.append((name.rstrip(b"\0").decode(),seg.rstrip(b"\0").decode(),addr,siz,off))
   if cmd==0x26:
    off,sz=struct.unpack_from('<II',self.data,at+8);cur=0x100000000;i=off
    while i<off+sz:
     v=0;shift=0
     while True:
      b=self.data[i];i+=1;v|=(b&127)<<shift;shift+=7
      if b<128:break
     if v==0:break
     cur+=v;self.starts.append(cur)
   at+=size
 def offset(self,va):
  for _,v,_,o,n in self.segments:
   if v<=va<v+n:return o+va-v
  raise ValueError('Address not file backed')
 def address(self,off):
  for _,v,_,o,n in self.segments:
   if o<=off<o+n:return v+off-o
  raise ValueError('Offset not mapped')
 def bytes(self,va,n):o=self.offset(va);return self.data[o:o+n]
 def u64(self,va):return struct.unpack('<Q',self.bytes(va,8))[0]
 def string(self,va):
  try:o=self.offset(va);e=self.data.index(0,o,o+300);return self.data[o:e].decode('utf8')
  except (ValueError,UnicodeError):return ''
 def dis(self,va,n=160):
  for i in Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(self.bytes(va,n),va):print(f'{i.address:#x}: {i.mnemonic} {i.op_str}')
 def names(self,pattern):
  out=[]
  for name,seg,va,n,o in self.sections:
   if name!='__cstring':continue
   pos=o
   for b in self.data[o:o+n].split(b'\0'):
    if re.search(pattern,b.decode('utf8',errors='replace'),re.I):out.append((va+pos-o,b.decode('utf8',errors='replace')))
    pos+=len(b)+1
  return out
 def refs(self,va):
  return [self.address(m.start()) for m in re.finditer(re.escape(struct.pack('<Q',va)),self.data) if m.start()%8==0]
 def registrations(self,pattern):
  text=next(x for x in self.sections if x[0]=='__text');lo,hi=text[2],text[2]+text[3]
  for va,name in self.names(pattern):
   for r in self.refs(va):
    f=self.u64(r+8)
    if lo<=f<hi:print(name,hex(r),hex(f))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['names','regs','dis','refs']);p.add_argument('value');p.add_argument('--size',type=int,default=192);a=p.parse_args();m=Image()
 if a.action=='dis':m.dis(int(a.value,0),a.size)
 elif a.action=='refs':print([hex(x) for x in m.refs(int(a.value,0))])
 elif a.action=='regs':m.registrations(a.value)
 else:
  for va,name in m.names(a.value):print(hex(va),name)

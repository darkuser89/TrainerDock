#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Offline Mach-O comparisons for explicitly pinned Control builds; no game writes."""
from pathlib import Path
import bisect,struct,hashlib
class Mach:
 def __init__(self,path):
  self.path=Path(path);self.data=self.path.read_bytes();self.segments=[];self.sections=[];self.functions=[];self.base=0;commands=[];o=32
  assert struct.unpack_from('<I',self.data)[0]==0xfeedfacf
  for _ in range(struct.unpack_from('<I',self.data,16)[0]):
   c,n=struct.unpack_from('<II',self.data,o);commands.append((c,self.data[o:o+n]))
   if c==0x19:
    name,vm,vs,fo,fs,_,_,ns,_=struct.unpack_from('<16sQQQQiiII',self.data,o+8);name=name.rstrip(b'\0').decode();self.segments.append((name,vm,vs,fo,fs))
    if name=='__TEXT':self.base=vm
    for j in range(ns):
     sect,seg,addr,size,offset=struct.unpack_from('<16s16sQQI',self.data,o+72+j*80);self.sections.append((seg.rstrip(b'\0').decode(),sect.rstrip(b'\0').decode(),addr,size,offset))
   o+=n
  for c,b in commands:
   if c==0x26:
    off,size=struct.unpack_from('<II',b,8);p=off;end=off+size;address=self.base
    while p<end:
     value=0;shift=0
     while True:
      z=self.data[p];p+=1;value|=(z&127)<<shift;shift+=7
      if z<128:break
     if not value:break
     address+=value;self.functions.append(address)
 def raw(self,vm,n):
  for _,v,_,o,s in self.segments:
   if v<=vm and vm+n<=v+s:return self.data[o+vm-v:o+vm-v+n]
  raise ValueError(hex(vm))
 def pointer(self,vm):
  value=struct.unpack('<Q',self.raw(vm,8))[0]
  if not value:return 0
  # Both pinned arm64 files use DYLD_CHAINED_PTR_64_OFFSET local rebases.
  if value>>63:return 0
  return self.base+(value&0xfffffffff)
 def string(self,vm):return self.raw(vm,256).split(b'\0',1)[0].decode(errors='replace')
 def words(self,start,end):return struct.unpack('<'+'I'*((end-start)//4),self.raw(start,end-start))
 def bounds(self,address):
  i=bisect.bisect_right(self.functions,address)-1
  if i<0 or i+1==len(self.functions):raise ValueError(hex(address))
  return self.functions[i],self.functions[i+1]
 def normalized(self,start,end):
  out=[];pc=None
  for w in self.words(start,end):
   raw=w;rn=(w>>5)&31
   if w&0x7c000000==0x14000000:w&=0xfc000000
   elif w&0xff000010==0x54000000:w&=0xff00001f
   elif w&0x7e000000==0x34000000:w&=0xff00001f
   elif w&0x7e000000==0x36000000:w&=0xfff8001f
   elif w&0x1f000000==0x10000000:w&=0x9f00001f
   elif w&0xff800000==0x91000000 and rn==pc:w&=0xffc003ff
   elif w&0x3b000000==0x39000000 and rn==pc:w&=0xffc003ff
   elif w&0x3b000000==0x18000000:w&=0xff00001f
   # Mask only an immediate ADRP pair; loaded object pointers are not PC-relative.
   pc=raw&31 if raw&0x9f000000==0x90000000 else None
   out.append(w)
  return struct.pack('<'+'I'*len(out),*out)
 def vtable(self,name):
  strings=[]
  for seg,sect,addr,size,off in self.sections:
   if sect not in ['__cstring','__const']:continue
   data=self.data[off:off+size];pos=0
   while True:
    i=data.find(name.encode()+b'\0',pos)
    if i<0:break
    begin=data.rfind(b'\0',0,i)+1;word=data[begin:i+len(name)]
    if word.lstrip(b'0123456789')==name.encode():strings.append(addr+begin)
    pos=i+1
  infos=[];tables=[]
  for seg,sect,addr,size,_ in self.sections:
   if seg!='__DATA_CONST':continue
   for p in range(addr,addr+size-16,8):
    if self.pointer(p+8) in strings:infos.append(p)
  for seg,sect,addr,size,_ in self.sections:
   if seg!='__DATA_CONST':continue
   for p in range(addr,addr+size-16,8):
    if self.pointer(p+8) in infos and self.raw(p,8)==b'\0'*8:tables.append(p+16)
  return tables

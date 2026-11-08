#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Resolve original IL2CPP method tokens to ARM64 RVAs without loading the game."""
from pathlib import Path
import importlib.util,struct,argparse
SPEC=importlib.util.spec_from_file_location('tld_metadata',Path(__file__).parents[1]/'VampireCrawlers/metadata.py')
META=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(META)
class Original:
 def __init__(self,app):
  self.metadata=META.Metadata(app/'Contents/Resources/Data/il2cpp_data/Metadata/global-metadata.dat')
  data=(app/'Contents/Frameworks/GameAssembly.dylib').read_bytes();magic,count=struct.unpack_from('>II',data)
  offset=0
  if magic==0xcafebabe:offset=next(x[2] for x in [struct.unpack_from('>IIIII',data,8+20*i) for i in range(count)] if x[0]==0x100000c)
  self.data=data[offset:];header=struct.unpack_from('<8I',self.data);at=32;self.segments=[]
  if header[0]!=0xfeedfacf:raise ValueError('Expected ARM64 Mach-O')
  for _ in range(header[4]):
   cmd,size=struct.unpack_from('<II',self.data,at)
   if cmd==0x19:self.segments.append(struct.unpack_from('<QQQQ',self.data,at+24))
   at+=size
  image,first,count=next(self.metadata.image(i) for i in range(self.metadata.images[1]) if self.metadata.image(i)[0]=='Assembly-CSharp.dll')
  self.types=[self.metadata.type(i) for i in range(first,first+count)]
  name=b'Assembly-CSharp.dll\0';positions=[];at=0
  while (at:=self.data.find(name,at))>=0:positions.append(self.vm(at));at+=len(name)
  candidates=[]
  for nameAddress in positions:
   packed=struct.pack('<Q',nameAddress);at=0
   while (at:=self.data.find(packed,at))>=0:
    if at%8==0:
     n,pointer=struct.unpack_from('<I4xQ',self.data,at+8)
     if 10000<n<200000:
      try:self.file(pointer+n*8-8);candidates.append((n,pointer))
      except ValueError:pass
    at+=8
  if len(candidates)!=1:raise ValueError(f'Original codegen module ambiguous: {candidates}')
  self.count,self.pointer=candidates[0]
 def file(self,vm):
  for addr,_,offset,size in self.segments:
   if addr<=vm<addr+size:return offset+vm-addr
  raise ValueError('Original pointer not file-backed')
 def vm(self,file):
  for addr,_,offset,size in self.segments:
   if offset<=file<offset+size:return addr+file-offset
  raise ValueError('Original file offset not mapped')
 def methods(self,names):
  for t in self.types:
   if (t['namespace']+'.'+t['name']) not in names and t['name'] not in names:continue
   for i in range(t['method'],t['method']+t['method_count']):
    m=struct.unpack_from('<7i4H',self.metadata.data,self.metadata.methods[0]+36*i);token=m[6]&0xffffff
    if not 1<=token<=self.count:raise ValueError('Method token outside original codegen table')
    fn=struct.unpack_from('<Q',self.data,self.file(self.pointer)+(token-1)*8)[0]
    params=[]
    for p in range(m[4],m[4]+m[-1]):
     name,_,typ=struct.unpack_from('<IIi',self.metadata.data,self.metadata.parameters[0]+12*p);params.append(self.metadata.string(name)+':'+str(typ))
    yield t,self.metadata.string(m[0]),params,fn,m[6]
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('app',type=Path);p.add_argument('classes',nargs='+');a=p.parse_args();o=Original(a.app)
 for t,n,args,fn,token in o.methods(a.classes):print(f"{t['namespace']}.{t['name']}::{n}({', '.join(args)}) token={token:#x} rva={fn:#x}")

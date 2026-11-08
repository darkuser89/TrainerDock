#!/usr/bin/env python3
"""Read-only arm64 address-reference inspection of the original Frostpunk 2 image."""
from Inspect import Image
import struct,sys,bisect
m=Image();text=next(s for s in m.sections if s[0]=='__text');base,size,off=text[2:];starts=m.starts

def refs(target):
 data=m.data[off:off+size]
 for i in range(0,len(data)-16,4):
  w=struct.unpack_from('<I',data,i)[0]
  if w&0x9f000000!=0x90000000:continue
  imm=((w>>5)&0x7ffff)<<2|((w>>29)&3)
  if imm&(1<<20):imm-=1<<21
  page=((base+i)&~4095)+(imm<<12)
  if page!=target&~4095:continue
  reg=w&31
  for j in range(4,28,4):
   v=struct.unpack_from('<I',data,i+j)[0]
   if v&0xffc00000==0x91000000 and (v>>5)&31==reg and page+((v>>10)&4095)==target:
    va=base+i;fn=starts[bisect.bisect_right(starts,va)-1];print(hex(va),hex(fn));break
if __name__=='__main__':
 if sys.argv[1]=='xrefs':refs(int(sys.argv[2],0))
 elif sys.argv[1]=='func':
  a=int(sys.argv[2],0);idx=bisect.bisect_right(starts,a)-1;print(hex(starts[idx]),hex(starts[idx+1]));m.dis(starts[idx],starts[idx+1]-starts[idx])

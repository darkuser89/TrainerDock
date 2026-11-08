#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only Frostpunk 2 branch/ObjC evidence helper; never launches the game."""
import argparse, array, bisect, struct
from Inspect import Image

def branches(m, targets):
 s=next(s for s in m.sections if s[0]=='__text'); words=array.array('I',m.bytes(s[2],s[3])); out=[]
 for i,w in enumerate(words):
  if (w&0x7c000000)!=0x14000000: continue
  d=w&0x3ffffff
  if d&0x2000000:d-=0x4000000
  a=s[2]+i*4;t=a+d*4
  if t in targets:
   f=m.starts[bisect.bisect_right(m.starts,a)-1];out.append((a,t,f))
 return out

def objc_selector(m,stub):
 # Apple selector stubs here use ADRP x1; LDR x1,[x1,#imm].
 from capstone import Cs,CS_ARCH_ARM64,CS_MODE_ARM
 ins=list(Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(m.bytes(stub,20),stub))
 if ins[0].mnemonic=='b': return objc_selector(m,int(ins[0].op_str[1:],16))
 if ins[0].mnemonic=='adrp' and ins[1].mnemonic=='ldr':
  page=int(ins[0].op_str.split('#')[1],16);w=struct.unpack('<I',m.bytes(stub+4,4))[0];ref=page+((w>>10)&0xfff)*8
  v=m.u64(ref);return m.string(0x100000000+(v&0xfffffffff))
 return ''
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['branches','selector','bytes']);p.add_argument('addresses',nargs='+');a=p.parse_args();m=Image();vs=[int(v,0) for v in a.addresses]
 if a.action=='branches':
  for x,t,f in branches(m,set(vs)):print(f'{x:#x} -> {t:#x}; function {f:#x}')
 elif a.action=='selector':
  for v in vs:print(hex(v),objc_selector(m,v))
 else:
  for v in vs:print(hex(v),m.bytes(v,16).hex())

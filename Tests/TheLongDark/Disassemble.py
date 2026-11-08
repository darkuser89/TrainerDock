#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only, bounded ARM64 disassembly of the identified original binary."""
import argparse,struct
from pathlib import Path
from capstone import Cs,CS_ARCH_ARM64,CS_MODE_ARM
p=argparse.ArgumentParser();p.add_argument('image',type=Path);p.add_argument('address',type=lambda x:int(x,0));p.add_argument('--size',type=int,default=256);a=p.parse_args()
if not 4<=a.size<=4096:raise ValueError('Bounded disassembly only')
with a.image.open('rb') as f:
 h=f.read(8);magic,count=struct.unpack('>II',h);offset=0
 if magic==0xcafebabe:
  entries=[struct.unpack('>IIIII',f.read(20)) for _ in range(count)]
  offset=next(x[2] for x in entries if x[0]==0x100000c)
 elif magic!=0xcffaedfe:raise ValueError('Unsupported original image')
 f.seek(offset);h=struct.unpack('<8I',f.read(32));commands=f.read(h[5]);at=0;found=None
 for _ in range(h[4]):
  cmd,size=struct.unpack_from('<II',commands,at)
  if cmd==0x19:
   vmaddr,vmsize,fileoff,filesize=struct.unpack_from('<QQQQ',commands,at+24)
   if vmaddr<=a.address and a.address+a.size<=vmaddr+filesize:found=offset+fileoff+a.address-vmaddr
  at+=size
 if found is None:raise ValueError('Address is not file-backed')
 f.seek(found);data=f.read(a.size)
 for ins in Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(data,a.address):print(f'{ins.address:#x}: {ins.mnemonic} {ins.op_str}')

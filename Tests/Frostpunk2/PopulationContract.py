#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Passive exact-original evidence for native population struct lifetime and ABI."""
from pathlib import Path
import re,struct,uuid
from Inspect import Image
from GameBindings import ptr
from capstone import Cs,CS_ARCH_ARM64,CS_MODE_ARM

def ins(m,a,n):return {i.address:(i.mnemonic,i.op_str) for i in Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(m.bytes(a,n),a)}
def run():
 m=Image();at=32;identified=False
 for _ in range(struct.unpack_from('<I',m.data,16)[0]):
  cmd,size=struct.unpack_from('<II',m.data,at)
  if cmd==0x1b:assert str(uuid.UUID(bytes=m.data[at+8:at+24])).upper()=='10F7F2EA-0D13-337E-BF07-ABA47A4549CF';identified=True
  at+=size
 assert identified
 source=(Path(__file__).resolve().parents[2]/'Modules/frostpunk-2/Sources/Population.mm').read_text()
 bindings=re.findall(r'\{"([^"]+)",(0x[0-9a-f]+)ULL,\{([^}]+)\}\}',source);assert len(bindings)==11
 for name,a,b in bindings:
  expected=bytes(int(x,0) for x in b.split(','));assert len(expected)==16 and m.bytes(int(a,0),16)==expected,name
 # Named UHT descriptor registers the ops factory and exact value size/alignment.
 d=0x10bc2a048
 assert m.string(ptr(m.u64(d+24)))=='PXCommunitySizeChangeParameters'
 assert ptr(m.u64(d+16))==0x105a441f4
 assert struct.unpack('<HHH',m.bytes(d+40,6))==(13,72,8)
 assert m.bytes(0x10a926f88,8)==struct.pack('<II',72,8)
 assert ptr(m.u64(0x10b0c8cb8))==0x10bc2b250
 assert ptr(m.u64(0x10bc2b260+24))==0x105a4478c
 assert ptr(m.u64(0x10bc2b260+40))==0x105a4482c
 assert ptr(m.u64(0x10bc2b260+8))==0x105a44778
 # The original placement constructor initializes all 72 bytes and calls FText.
 code=ins(m,0x105a4478c,84)
 assert code[0x105a44798]==('mov','x19, x1')
 assert code[0x105a4479c]==('add','x0, x1, #0x18')
 assert code[0x105a447a0]==('str','xzr, [x1, #0x40]')
 assert code[0x105a447a8]==('stp','q0, q0, [x1, #0x20]')
 assert code[0x105a447ac]==('stp','q0, q0, [x1]')
 assert code[0x105a447b0]==('bl','#0x10081f5e4')
 assert code[0x105a447b8]==('strh','w8, [x19, #0x28]')
 assert code[0x105a447c4]==('str','w8, [x19, #0x2c]')
 assert ins(m,0x10081f5e4,4)[0x10081f5e4]==('b','#0x100826da0')
 # Destruction releases the native TArray and FText's retained data using originals.
 code=ins(m,0x105a4482c,64)
 assert code[0x105a4483c]==('ldr','x0, [x1, #0x30]')
 assert code[0x105a44844]==('bl','#0x1007da780')
 assert code[0x105a44848]==('ldr','x0, [x19, #0x18]')
 assert code[0x105a44854]==('ldr','x8, [x8, #0x18]')
 # The registered original thunk passes an independent owned 72-byte temporary.
 code=ins(m,0x10637fc98,164)
 assert code[0x10637fcb0]==('ldr','x8, [x8, #0x10]') # FText retain
 assert code[0x10637fd08]==('mov','x2, sp')
 assert code[0x10637fd14]==('bl','#0x10717ad00')
 assert code[0x10637fd34]==('ldr','x8, [x8, #0x18]') # Caller-owned destruction
 assert ins(m,0x106381b88,12)[0x106381b90]==('bl','#0x10717a37c')
 # Exact UHT object type getter slots: city component, community type.
 assert ptr(m.u64(0x10bc29d38+56))==0x1068f0cc4
 assert ptr(m.u64(0x10bc29d78+56))==0x105f51ab0
 # Original non-killing path forwards minimum remaining from params +44.
 code=ins(m,0x10717ae88,0xc8)
 assert code[0x10717aec0]==('ldr','w26, [x20, #0x2c]')
 assert code[0x10717af28]==('str','w26, [sp, #4]')
 assert code[0x10717af4c]==('bl','#0x10716e5c4')
 # Signed native addition is clamped to max(minimumRemaining, original+delta).
 code=ins(m,0x10716e5e8,0x34)
 assert code[0x10716e5ec]==('mov','x21, x3')
 assert code[0x10716e614]==('ldr','w22, [x29, #0x14]')
 code=ins(m,0x10716e7d4,16)
 assert code[0x10716e7d8]==('add','w8, w23, w21')
 assert code[0x10716e7dc]==('cmp','w22, w8')
 assert code[0x10716e7e0]==('csel','w22, w22, w8, gt')
 code=ins(m,0x10716e890,48)
 assert code[0x10716e894]==('sub','w2, w22, w8')
 assert code[0x10716e8bc]==('bl','#0x10716e168')
 print('PASS: 11 native population signatures, named 72-byte/align8 struct ops, FText construction/destruction, caller-owned ABI, count getter and signed non-killing clamp. No game executed.')
if __name__=='__main__':run()

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Verify exact original thread/cursor ABI evidence without executing game code."""
from pathlib import Path
import re, struct, uuid
from Inspect import Image
from ThreadInputInspect import objc_selector, branches
from capstone import Cs,CS_ARCH_ARM64,CS_MODE_ARM

def pointer(m,va):
 value=m.u64(va)
 assert not(value>>63),'Unexpected bound pointer'
 return 0x100000000+(value&0xfffffffff)

def dis(m,va,size):return list(Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(m.bytes(va,size),va))

def run():
 m=Image();cursor=32;identified=False
 for _ in range(struct.unpack_from('<I',m.data,16)[0]):
  cmd,size=struct.unpack_from('<II',m.data,cursor)
  if cmd==0x1b:
   assert str(uuid.UUID(bytes=m.data[cursor+8:cursor+24])).upper()=='10F7F2EA-0D13-337E-BF07-ABA47A4549CF'
   identified=True
  cursor+=size
 assert identified
 header=Path(__file__).resolve().parents[2]/'Modules/frostpunk-2/Sources/ThreadInputBindings.h'
 checks=re.findall(r'\{"([^"]+)",(0x[0-9a-f]+)ULL,\{([^}]+)\}\}',header.read_text())
 assert len(checks)==21
 for name,address,raw in checks:
  va=int(address,16);expected=bytes(int(x,16) for x in raw.split(','));assert len(expected)==16
  assert m.bytes(va,16)==expected,name
 assert objc_selector(m,0x107c0e9bc)=='gameThread'
 assert objc_selector(m,0x107c0e990)=='currentThread'
 assert objc_selector(m,0x107c0e98c)=='isGameThread'
 assert objc_selector(m,0x107c0e988)=='mainThread'
 assert objc_selector(m,0x107c0f168)=='set'
 assert dis(m,0x100c993bc,4)[0].op_str=='w8, [x19, #0x120]'
 # Original game-thread dispatcher argument preservation and destination identity.
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x10087a854,0x90)}
 assert ins[0x10087a868]==('mov','x19, x2')
 assert ins[0x10087a86c]==('mov','x21, x1')
 assert ins[0x10087a870]==('mov','x20, x0')
 assert ins[0x10087a87c]==('bl','#0x107c0e9bc')
 assert ins[0x10087a888]==('bl','#0x107c0e990')
 assert ins[0x10087a898]==('ldr','x0, [x8, #0x738]')
 assert ins[0x10087a8c4]==('b','#0x10087a73c')
 assert ins[0x10087a8c8]==('ldr','x1, [x20, #0x10]')
 assert ins[0x10087a8e0]==('br','x1')
 # Original caller constructs an NSArray and explicitly passes wait=false.
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x100c81bd0,0x1c)}
 assert ins[0x100c81be0]==('mov','x0, sp')
 assert ins[0x100c81be4]==('mov','w2, #0')
 assert ins[0x100c81be8]==('bl','#0x10087a854')
 # Constructor and virtual table prove native C++ cursor methods; no AppKit ivars.
 assert pointer(m,0x10b16b5d8)==0x100c99320
 assert pointer(m,0x10b16b5f0)==0x100c99434
 assert pointer(m,0x10b16b5f8)==0x100c9943c
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x100c91134,0x40)}
 assert ins[0x100c91134]==('strb','w1, [x0, #0xa0]')
 assert ins[0x100c91138]==('ldr','x0, [x0, #8]')
 assert ins[0x100c9113c]==('b','#0x100c91140')
 assert ins[0x100c91168]==('strb','w1, [x0, #0x111]')
 assert ins[0x100c9116c]==('eor','w0, w1, #1')
 assert ins[0x100c91170]==('bl','#0x107c0eff4')
 # Native reflection thunk -> viewport setter and verified controller vtable slots.
 assert pointer(m,0x10b649278)==0x10367da30
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x10367daf4,0x14)}
 assert ins[0x10367db04]==('bl','#0x1036b2f10')
 for address,offset in [(0x1036b2f10,'0x3a2'),(0x1036b3020,'0x3a4'),(0x1036b3034,'0x3a3')]:
  ins=dis(m,address,20)
  assert ins[0].mnemonic=='ldrb' and offset in ins[0].op_str
  assert ins[3].mnemonic=='strb' and offset in ins[3].op_str
 assert pointer(m,0x10b735e60)==0x10353571c # Move at vtable +0x850
 assert pointer(m,0x10b735e78)==0x103535754 # Look at vtable +0x868
 assert pointer(m,0x10b7363a0)==0x103b3f704 # SetInputMode at +0xd90
 assert pointer(m,0x10b39a300)==0x102ea5af0 # Registered original exec thunk
 assert pointer(m,0x10b39a320)==0x102ea6074 # UIOnly original exec thunk
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x102ea5c8c,0xc)}
 assert ins[0x102ea5c94]==('bl','#0x102ea5ca8')
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x102ea61b8,0xc)}
 assert ins[0x102ea61c0]==('bl','#0x102ea61d4')
 ins=dis(m,0x103b2fcd0,16)
 assert ins[0].op_str=='w8, [x0, #0x544]' and ins[1].op_str=='w8, w8, #1'
 # Named SetFocusToGameViewport thunk -> Slate singleton/focus entry point.
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x102ea5874,0x14)}
 assert ins[0x102ea587c]==('ldr','x0, [x8, #0xfa0]')
 assert ins[0x102ea5884]==('b','#0x100ed4da8')
 # Per-user release verifies bounds, enumerates pointer IDs, emits loss, erases.
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x100ed9774,0x50)}
 assert ins[0x100ed9784]==('tbnz','w1, #0x1f, #0x100ed97d0')
 assert ins[0x100ed9788]==('ldr','w8, [x0, #0x308]')
 assert ins[0x100ed9794]==('ldr','x8, [x0, #0x300]')
 assert ins[0x100ed97c0]==('bl','#0x100f0f41c')
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x100f0f41c,0x64)}
 assert ins[0x100f0f434]==('add','x0, x0, #0x148')
 assert ins[0x100f0f45c]==('bl','#0x100f0f16c')
 ins={i.address:(i.mnemonic,i.op_str) for i in dis(m,0x100f0f2bc,0x20)}
 assert ins[0x100f0f2c4]==('stp','w8, w9, [sp]') # user ID and pointer ID
 assert ins[0x100f0f2cc]==('ldr','x8, [x8, #0x1b0]')
 # No asynchronous callback or synthetic result is presented as an in-game proof.
 print(f'PASS: {len(checks)} exact 16-byte bindings, original GameThread ABI/selector/callsite and cursor layout. No game executed.')
if __name__=='__main__':run()

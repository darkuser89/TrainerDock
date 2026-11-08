#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Passive original-code evidence for scoped wear, demolition and council APIs."""
from pathlib import Path
import re,struct,uuid
from Inspect import Image
from GameBindings import ptr
from capstone import Cs,CS_ARCH_ARM64,CS_MODE_ARM

def code(m,a,n):return {i.address:(i.mnemonic,i.op_str) for i in Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(m.bytes(a,n),a)}
def run():
 m=Image();at=32;identified=False
 for _ in range(struct.unpack_from('<I',m.data,16)[0]):
  cmd,size=struct.unpack_from('<II',m.data,at)
  if cmd==0x1b:assert str(uuid.UUID(bytes=m.data[at+8:at+24])).upper()=='10F7F2EA-0D13-337E-BF07-ABA47A4549CF';identified=True
  at+=size
 assert identified
 source=(Path(__file__).resolve().parents[2]/'Modules/frostpunk-2/Sources/Operations.mm').read_text()
 checks=re.findall(r'\{"([^"]+)",(0x[0-9a-f]+)ULL,\{([^}]+)\}\}',source);assert len(checks)==24
 for name,address,raw in checks:
  expected=bytes(int(x,0) for x in raw.split(','));assert len(expected)==16 and m.bytes(int(address,0),16)==expected,name
 # Exact registered-set enumeration in both original operation and wear ticks.
 c=code(m,0x10733af0c,0x150)
 assert c[0x10733af0c]==('add','x24, x0, #0x2a0')
 assert c[0x10733af14]==('ldr','w25, [x0, #0x2b8]')
 assert c[0x10733af1c]==('ldr','x8, [x19, #0x2b0]')
 assert c[0x10733b048]==('ldr','x9, [x19, #0x290]')
 assert c[0x10733b04c]==('sbfiz','x8, x8, #4, #0x20')
 assert c[0x10733b050]==('ldr','x22, [x9, x8]')
 c=code(m,0x10778b6d8,0x220)
 assert c[0x10778b6d8]==('add','x24, x19, #0x2a0')
 assert c[0x10778b6dc]==('ldr','w25, [x19, #0x2b8]')
 assert c[0x10778b7f8]==('ldr','x9, [x19, #0x290]')
 assert c[0x10778b7fc]==('sbfiz','x8, x8, #4, #0x20')
 assert c[0x10778b8c8]==('bl','#0x10778b94c')
 # Native setter uses float s0, the actual component, owner, bounds and events.
 c=code(m,0x10778b96c,0x130)
 assert c[0x10778b96c]==('fmov','s8, s0')
 assert c[0x10778b970]==('mov','x19, x1')
 assert c[0x10778b980]==('ldr','x21, [x19, #0x90]')
 assert c[0x10778b9dc]==('bl','#0x107788dd8')
 assert code(m,0x10778ba68,4)[0x10778ba68]==('str','s8, [x19, #0xb8]')
 # Deconstruction creates an operation targeting the building, which differs
 # from the temporary operation-carrier Actor in operation.OwnerActor.
 c=code(m,0x107713d28,16)
 assert c[0x107713d28]==('ldr','x1, [x19, #0x90]')
 assert c[0x107713d30]==('bl','#0x10733a0fc')
 assert c[0x107713d34]==('str','x0, [x19, #0x270]')
 c=code(m,0x10733a11c,16);assert c[0x10733a120]==('mov','x22, x1')
 assert code(m,0x10733a2cc,4)[0x10733a2cc]==('str','x22, [x21, #0xe8]')
 p=0x10c075730
 assert m.string(ptr(m.u64(p)))=='TargetActor'
 assert struct.unpack('<I',m.bytes(p+24,4))[0]&63==18
 assert struct.unpack('<H',m.bytes(p+50,2))[0]==0xe8
 assert ptr(m.u64(0x10c0758e8+40))==0x10c075860
 assert any(ptr(m.u64(0x10c075860+i*8))==p for i in range(16))
 # Original callback proves both real completion readbacks before queued removal.
 c=code(m,0x107714448,0x78)
 assert c[0x107714448]==('ldr','x20, [x1, #0xe8]')
 assert c[0x107714494]==('ldr','x8, [x0, #0x270]')
 assert c[0x1077144b4]==('str','xzr, [x20, #0x270]')
 assert c[0x1077144bc]==('strb','w8, [x20, #0x260]')
 # FinishOperation is the same original called by OnLogicTick after IsFinished.
 assert code(m,0x10733b154,12)[0x10733b158]==('bl','#0x107339140')
 assert code(m,0x10733b1a0,12)[0x10733b1a8]==('bl','#0x10733a7e0')
 assert code(m,0x10733a85c,8)[0x10733a860]==('str','w8, [x19, #0xb8]')
 # The one-shot council action only skips Maintenance(4), starts a new session
 # and calls the original phase event rather than silently changing data fields.
 c=code(m,0x1075f0acc,0x64)
 assert c[0x1075f0ad0]==('cmp','w8, #4')
 assert c[0x1075f0aec]==('strb','w8, [x20, #0x1c0]')
 assert c[0x1075f0af0]==('ldr','w8, [x20, #0x1c4]')
 assert c[0x1075f0af4]==('add','w8, w8, #1')
 assert c[0x1075f0af8]==('str','w8, [x20, #0x1c4]')
 assert c[0x1075f0b28]==('bl','#0x1075ea4f4')
 print('PASS: 24 exact operation bindings; original typed registries, wear ABI, demolition target/completion callback and one-shot council phase transition. No game executed.')
if __name__=='__main__':run()

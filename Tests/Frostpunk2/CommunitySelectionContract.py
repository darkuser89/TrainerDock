#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Passive original faction-card selection ABI evidence; never executes game code."""
from pathlib import Path
import re,struct,uuid
from capstone import Cs,CS_ARCH_ARM64,CS_MODE_ARM
from Inspect import Image
from GameBindings import ptr,class_name

def code(m,address,size):
 return {i.address:(i.mnemonic,i.op_str) for i in Cs(CS_ARCH_ARM64,CS_MODE_ARM).disasm(m.bytes(address,size),address)}

def run():
 m=Image();at=32;identified=False
 for _ in range(struct.unpack_from('<I',m.data,16)[0]):
  command,size=struct.unpack_from('<II',m.data,at)
  if command==0x1b:
   assert str(uuid.UUID(bytes=m.data[at+8:at+24])).upper()=='10F7F2EA-0D13-337E-BF07-ABA47A4549CF'
   identified=True
  at+=size
 assert identified
 source=(Path(__file__).resolve().parents[2]/'Modules/frostpunk-2/Sources/CommunitySelection.mm').read_text()
 anchors=re.findall(r'\{(0x[0-9a-f]+)ULL,\{([^}]+)\}\}',source)
 assert len(anchors)==8
 for address,raw in anchors:
  expected=bytes(int(x,0) for x in raw.split(','))
  assert len(expected)==16 and m.bytes(int(address,0),16)==expected,address

 # Original utility metadata: native/static getter takes one world-context
 # UObject pointer and returns the actual PXCommunityComponent pointer.
 definition=0x10be8bdd8
 assert class_name(m,ptr(m.u64(definition)))=='PXUtopiaToolPanelsUtils'
 assert m.string(ptr(m.u64(definition+16)))=='GetCurrentCommunity'
 assert struct.unpack('<HH',m.bytes(definition+48,4))==(2,16)
 assert struct.unpack('<I',m.bytes(definition+56,4))[0]&0x2400==0x2400
 array=ptr(m.u64(definition+40));parameters=[ptr(m.u64(array+i*8)) for i in range(2)]
 for p,name,offset in zip(parameters,('worldContextObject','ReturnValue'),(0,8)):
  assert m.string(ptr(m.u64(p)))==name
  assert struct.unpack('<I',m.bytes(p+24,4))[0]&63==18
  assert struct.unpack('<H',m.bytes(p+50,2))[0]==offset
 assert ptr(m.u64(parameters[1]+56))==0x106735220
 assert ptr(m.u64(0x10be8c898+8))==0x1063114fc
 assert code(m,0x106311564,4)[0x106311564]==('bl','#0x106b58c90')

 # Resolve the context's World and retrieve the exact subsystem from that
 # World's collection. Do not choose any arbitrary live subsystem instance.
 c=code(m,0x106b58c90,0xe4)
 assert c[0x106b58cb4]==('bl','#0x103e47020')
 assert c[0x106b58cbc]==('bl','#0x105ad6030')
 assert c[0x106b58d1c]==('add','x0, x19, #0x880')
 assert c[0x106b58d20]==('bl','#0x103ddc2b4')
 assert c[0x106b58d60]==('bl','#0x106bfa24c')
 assert code(m,0x106bfa24c,8)=={0x106bfa24c:('ldr','x0, [x0, #0x118]'),0x106bfa250:('ret','')}
 # GetCurrentCommunityType derives Type from the same selected component.
 c=code(m,0x106bfa358,0x60)
 assert c[0x106bfa368]==('ldr','x19, [x0, #0x118]')
 assert c[0x106bfa3a0]==('ldr','x0, [x19, #0xb0]')
 # The native faction panel's own initialization consumes exactly this source.
 c=code(m,0x106cf6f30,0x18)
 assert c[0x106cf6f38]==('bl','#0x106bfa24c')
 assert c[0x106cf6f44]==('bl','#0x10610fae8')
 # Opening writes the selected component; closing retains the game's selection.
 assert code(m,0x106bfa3ec,4)[0x106bfa3ec]==('str','x1, [x19, #0x118]')
 assert not any(op.startswith('str') and '#0x118]' in operands for op,operands in code(m,0x106bfa438,0x44).values())
 print('8 original anchors and faction-card selection metadata/World-owner/getter chain verified; no game executed.')

if __name__=='__main__':run()

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Validate reflection anchor bytes against the identified, unmodified original."""
from pathlib import Path
from Inspect import Image
import re,struct,uuid
m=Image();at=32;found=None
for _ in range(struct.unpack_from('<I',m.data,16)[0]):
 cmd,size=struct.unpack_from('<II',m.data,at)
 if cmd==0x1b:found=str(uuid.UUID(bytes=m.data[at+8:at+24])).upper()
 at+=size
assert found=='10F7F2EA-0D13-337E-BF07-ABA47A4549CF',found
header=Path(__file__).resolve().parents[2]/'Modules/frostpunk-2/Sources/ReflectionBindings.h'
anchors=re.findall(r'\{"([^"]+)",0x([0-9a-f]+)ULL,\{([^}]+)\}\}',header.read_text())
assert len(anchors)==15
for name,address,byte_list in anchors:
 expected=bytes(int(x.strip(),16) for x in byte_list.split(','));assert len(expected)==16
 assert m.bytes(int(address,16),16)==expected,name
assert (m.u64(0x10b1626a8)&0xfffffffff)+0x100000000==0x100be2e78
print('Confirmed original UUID, 15 reflection anchors and ProcessEvent vtable slot. No execution.')

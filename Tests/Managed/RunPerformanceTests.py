#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Real backend idle/metadata boundaries; no game launch or product replacement."""
from pathlib import Path
import argparse
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
parser=argparse.ArgumentParser()
parser.add_argument('--modules',nargs='*',help='Only these changed modules; omitted means all.')
args=parser.parse_args()
selected=None if args.modules is None else set(args.modules)
if selected is not None and not selected.intersection({'the-long-dark','vampire-crawlers','terraria'}):
    print('No changed managed-runtime trainer selected; no performance fixtures required.')
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix='trainerdock-managed-performance-',dir='/private/tmp') as raw:
    stage=Path(raw)
    subprocess.run(['xcrun','clang++','-std=c++17','-O2','-Wall','-Wextra','-Werror',
                    str(ROOT/'Tests/Managed/MetadataCacheTests.cpp'),'-o',str(stage/'MetadataCacheTests')],check=True)
    subprocess.run([str(stage/'MetadataCacheTests')],check=True)
    if selected is None or 'terraria' in selected:
        original=(ROOT/'Modules/terraria/Sources/TerrariaBackend.mm').read_text()
        first=original.index('uintptr_t count=api.arrayLength(colors);')
        end=original.index('s.lightCells+=count;',first)+len('s.lightCells+=count;')
        light=stage/'LightFillTests.cpp'
        light.write_text((ROOT/'Tests/Managed/LightFillTests.cpp.in').read_text().replace('__ACTUAL_LIGHT_FILL__',original[first:end]))
        subprocess.run(['xcrun','clang++','-std=c++17','-O2','-Wall','-Wextra','-Werror',str(light),'-o',str(stage/'LightFillTests')],check=True)
        subprocess.run([str(stage/'LightFillTests')],check=True)
    for module,tag in [('the-long-dark','TLD'),('vampire-crawlers','VC'),('terraria','TR')]:
        if selected is not None and module not in selected:continue
        source=ROOT/'Modules'/module/'Sources'
        includes=[source,ROOT/'ModuleSDK']
        names=['IL2CPP.mm','MemoryAccess.m','TrainerFeatures.m'] if tag!='TR' else ['Mono.mm','TrainerFeatures.m']
        if tag=='TLD':names+=['SaveGuard.mm']
        objects=[]
        for name in names:
            output=stage/(tag+'-'+name+'.o');build.compile_object(source/name,output,includes);objects.append(output)
        output=stage/(tag+'-IdleFrameTests.o')
        build.compile_object(ROOT/'Tests/Managed/IdleFrameTests.mm',output,includes,['MHT_IDLE_'+tag+'=1'])
        executable=stage/(tag+'-IdleFrameTests');build.link([output,*objects],executable);build.run([executable])
        if tag!='TR':
            output=stage/(tag+'-IL2CPPMetadataTests.o')
            build.compile_object(ROOT/'Tests/Managed/IL2CPPMetadataTests.mm',output,includes,['MHT_METADATA_VC=1'] if tag=='VC' else [])
            executable=stage/(tag+'-IL2CPPMetadataTests');build.link([output,*[o for o in objects if o.name.endswith('IL2CPP.mm.o')]],executable);build.run([executable])
        if tag=='TLD':
            output=stage/'GearListTests.o';build.compile_object(ROOT/'Tests/Managed/GearListTests.mm',output,includes)
            executable=stage/'GearListTests';build.link([output,*[o for o in objects if o.name.endswith('IL2CPP.mm.o')]],executable);build.run([executable])
print('PASS: selected managed-runtime idle/metadata performance boundaries. No games launched.' if selected is not None else
      'PASS: actual TLD, Vampire Crawlers and Terraria idle/metadata performance boundaries. No games launched.')

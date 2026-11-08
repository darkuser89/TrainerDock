#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build the bounded read-only probe outside the repository; never starts a game."""
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=Path('/private/tmp/trainerdock-the-long-dark')
SRC=ROOT/'Modules/the-long-dark/Sources'
OUT.mkdir(exist_ok=True)
objects=[]
for source in (SRC/'IL2CPP.mm',SRC/'UnityLoop.mm',SRC/'GameProfile.m',Path(__file__).with_name('Probe.mm')):
 obj=OUT/(source.stem+'.o');objects.append(str(obj))
 flags=['-std=c++17'] if source.suffix=='.mm' else []
 subprocess.run(['xcrun','clang','-c','-arch','arm64','-mmacosx-version-min=27.0','-fobjc-arc','-fblocks','-Wall','-Wextra','-Werror','-I'+str(SRC),*flags,str(source),'-o',str(obj)],check=True)
subprocess.run(['xcrun','clang++','-dynamiclib','-arch','arm64','-mmacosx-version-min=27.0',*objects,'-framework','Foundation','-framework','AppKit','-framework','Security','-o',str(OUT/'Probe.dylib')],check=True)
subprocess.run(['codesign','--force','--sign','-',str(OUT/'Probe.dylib')],check=True)
for name in ('Launch','Query'):
 subprocess.run(['xcrun','swiftc','-module-cache-path',str(OUT/'SwiftCache'),'-target','arm64-apple-macos27.0',str(Path(__file__).with_name(name+'.swift')),'-o',str(OUT/name)],check=True)

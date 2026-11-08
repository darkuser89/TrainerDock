#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build private passive diagnostics and verify original identity; never launch."""
from pathlib import Path
import sys,json,subprocess
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'script'));import build
out=Path.home()/'Library/Developer/TrainerDock/InZOITest';out.mkdir(parents=True,exist_ok=True)
data=Path('/private/tmp/trainerdock-inzoi');data.mkdir(exist_ok=True);data.chmod(0o700)
if (out/'Probe.dylib').exists() and subprocess.run(['lsof','-t',str(out/'Probe.dylib')],capture_output=True).stdout.strip():raise SystemExit('Loaded probe is protected')
src=ROOT/'Modules/inzoi/Sources';include=[src,ROOT/'Core']
build.compile_object(ROOT/'Tests/InZOI/Probe.mm',out/'Probe.o',[]);build.link([out/'Probe.o'],out/'Probe.dylib',True)
build.run(['codesign','--force','--sign','-','--timestamp=none',out/'Probe.dylib'])
for name,source in [('GameIdentity',ROOT/'Core/GameIdentity.m'),('ProfileCheck',ROOT/'Tests/TheLongDark/ProfileCheck.m'),('GameIdentityTests',ROOT/'Tests/GameIdentityTests.m')]:build.compile_object(source,out/(name+'.o'),include)
build.link([out/'ProfileCheck.o',out/'GameIdentity.o'],out/'ProfileCheck');build.link([out/'GameIdentityTests.o',out/'GameIdentity.o'],out/'GameIdentityTests');build.run([out/'GameIdentityTests'])
m=json.loads((src.parent/'Module.json').read_text());m['profiles'][0]['enabled']=True
config=dict(schemaVersion=1,app=dict(name='inZOI',bundleIdentifier='local.trainerdock.test.inzoi',version='1',build='1'),profiles=m['profiles']);(out/'ProbeConfig.json').write_text(json.dumps(config))
build.run([out/'ProfileCheck',out/'ProbeConfig.json','steam-arm64-26264076','/Volumes/Mac Games/SteamLibrary/steamapps/common/inZOI/inZOI.app'])
build.run(['xcrun','swiftc','-module-cache-path',out/'SwiftCache','-target','arm64-apple-macos27.0',ROOT/'Tests/InZOI/Launch.swift','-o',out/'Launch'])
print('PASS: passive probe and exact original identity. No game started.')

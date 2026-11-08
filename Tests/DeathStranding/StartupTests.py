#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Exercise real first-inserted startup in a disposable, unrelated test app."""
from pathlib import Path
import json,os,plistlib,struct,subprocess,sys,uuid
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
import build
stage=Path(sys.argv[1]).resolve()
app=stage/'StartupFixture.app';contents=app/'Contents';mac=contents/'MacOS';mac.mkdir(parents=True,exist_ok=True)
exe=mac/'StartupFixture';obj=stage/'StartupFixture.o'
build.compile_object(ROOT/'Tests/DeathStranding/StartupFixture.m',obj,[ROOT/'ModuleSDK'])
build.link([obj,stage/'MHTProtocol.o'],exe)
(contents/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.trainerdock.ds.startup-test',CFBundleExecutable=exe.name,CFBundlePackageType='APPL')))
data=exe.read_bytes();pos=32;identity=None
for _ in range(struct.unpack_from('<I',data,16)[0]):
    command,size=struct.unpack_from('<II',data,pos)
    if command==0x1b:identity=str(uuid.UUID(bytes=data[pos+8:pos+24])).upper()
    pos+=size
assert identity
profile=dict(id='fixture',name='Unrelated synthetic startup fixture',enabled=True,bundleIdentifier='local.trainerdock.ds.startup-test',executable=exe.name,uuids=[identity])
config=stage/'StartupConfig.json';config.write_text(json.dumps(dict(schemaVersion=1,app=dict(name='Fixture',bundleIdentifier=profile['bundleIdentifier'],version='1',build='1'),profiles=[profile])))
profile_path=stage/'StartupProfile.json';profile_path.write_text(json.dumps(profile))
env=dict(os.environ);env.update(TD_STARTUP_PROFILE=str(profile_path),DYLD_INSERT_LIBRARIES=str(stage/'Trainer.dylib'),MHT_SESSION=str(uuid.uuid4()),MHT_MODULE='death-stranding',MHT_PROFILE='fixture',MHT_CONFIG=str(stage/'missing-external-runtime-configuration.json'),MHT_TARGET=str(exe))
build.run([exe],env=env)

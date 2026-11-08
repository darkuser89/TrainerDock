#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Check every native overlay in isolation. No game/adapter/runtime is linked."""
from pathlib import Path
import json,plistlib,sys,tempfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'script'))
import build

def main():
    with tempfile.TemporaryDirectory(prefix='trainerdock-overlay-titles-',dir='/private/tmp') as temporary:
        stage=Path(temporary);cache={};count=0
        def compile(path,source,defines,arch):
            key=(path,source,tuple(defines),arch)
            if key not in cache:
                obj=stage/('object-'+str(len(cache))+'.o')
                build.compile_object(path,obj,[source,ROOT/'ModuleSDK'],defines,architecture=arch);cache[key]=obj
            return cache[key]
        for module in sorted((ROOT/'Modules').glob('*/Build.json')):
            config=json.loads(module.read_text());metadata=json.loads(module.with_name('Module.json').read_text())
            if config.get('developmentOnly'):continue
            source=(module.parent/config.get('sourceRoot','Sources')).resolve();defines=list(config.get('defines',[]));arch=config.get('architecture','arm64')
            if config.get('family')=='CrimsonDesert':defines.append('TEST_CRIMSON=1')
            names=['Overlay.m','TrainerMaterial.m','OverlaySettings.m','OverlayShortcuts.m',*config['catalogSources']]
            objects=[compile(source/n,source,defines,arch) for n in dict.fromkeys(names)]
            objects.extend(compile(ROOT/'ModuleSDK'/n,source,defines,arch) for n in ['MHTGlassIntensity.m','MHTOverlayHost.m'])
            objects.append(compile(ROOT/'Tests/OverlayTitleTests.m',source,defines,arch))
            contents=stage/(metadata['id']+'.app')/'Contents';(contents/'MacOS').mkdir(parents=True)
            (contents/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=metadata['profiles'][0]['bundleIdentifier'],CFBundleExecutable='TitleCheck',CFBundlePackageType='APPL')))
            executable=contents/'MacOS/TitleCheck';build.link(objects,executable,architecture=arch)
            build.run([executable,metadata['name']]);count+=1
        print(f'PASS: all {count} trainer game headings checked. Temporary products removed; no game started.')

if __name__=='__main__':main()

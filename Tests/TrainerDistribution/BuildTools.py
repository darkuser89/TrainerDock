#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Compile distribution boundary tools outside the checkout; never launch games."""
import importlib.util
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
spec=importlib.util.spec_from_file_location('trainerdock_build',ROOT/'script/build.py')
build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
def compile_tool(source,output):
    output=Path(output);output.parent.mkdir(parents=True,exist_ok=True)
    sources=[ROOT/'Core'/name for name in ['MHTModule.m','MHTTrainerStore.m','MHTTrainerArchive.m','GameIdentity.m']]+[ROOT/source]
    objects=[]
    for item in sources:
        obj=output.parent/(item.stem+'.o');build.compile_object(item,obj,[ROOT/'Core',ROOT/'ModuleSDK','/opt/homebrew/opt/libarchive/include']);objects.append(obj)
    build.link(objects,output,extra_flags=['-larchive.2'])
    for obj in objects:obj.unlink()
if __name__=='__main__':
    import sys
    source='Tests/TrainerDistribution/DownloadSmoke.m' if len(sys.argv)>2 and sys.argv[2]=='--download-smoke' else 'Tests/TrainerDistribution/ImportLegacy.m'
    compile_tool(source,sys.argv[1])

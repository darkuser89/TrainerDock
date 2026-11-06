#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Compile/check the neutral source template without installing it or launching games."""
import json
from pathlib import Path
import subprocess
import tempfile
import build

ROOT=Path(__file__).resolve().parent.parent
def main():
    subprocess.run(['python3','-B',str(ROOT/'Tests/test_trainer_template.py')],check=True)
    template=ROOT/'Templates/Trainer';source=template/'Sources'
    config=json.loads((template/'Build.json').read_text())
    with tempfile.TemporaryDirectory(prefix='mht-template-check-') as temp:
        stage=Path(temp);includes=[source,ROOT/'ModuleSDK'];objects={}
        for name in config['sources']:
            obj=stage/(name+'.o');build.compile_object(source/name,obj,includes);objects[name]=obj
        for name in config.get('sdkSources',[]):
            obj=stage/('SDK-'+name+'.o');build.compile_object(ROOT/'ModuleSDK'/name,obj,includes);objects[name]=obj
        common=stage/'MHTProtocol.o';build.compile_object(ROOT/'ModuleSDK/MHTProtocol.m',common,includes)
        build.link([common,*objects.values()],stage/'TemplateCheck.dylib',dynamic=True)
        test_obj=stage/'TrainerTemplateTests.o';build.compile_object(ROOT/'Tests/TrainerTemplateTests.m',test_obj,includes)
        executable=stage/'TrainerTemplateTests'
        build.link([test_obj,*[objects[n] for n in ('TrainerFeatures.m','GameAdapter.m','NativeAdapter.m','SelectionSettings.m','OverlaySettings.m')]],executable)
        build.run([executable])
        dpi_obj=stage/'HiDPITests.o';build.compile_object(ROOT/'Tests/HiDPITests.m',dpi_obj,includes)
        dpi_executable=stage/'HiDPITests'
        build.link([dpi_obj,common,*[obj for name,obj in objects.items() if name!='Runtime.m']],dpi_executable)
        build.run([dpi_executable])
        try:build.trainer(template,stage,stage,common)
        except ValueError as error:
            if 'Entwicklungs-Vorlage' not in str(error):raise
        else:raise AssertionError('Development template must never enter the product build.')
    print('PASS: template generation, native compilation and product-build guard. Temporary artifacts removed; no module installed.')
if __name__=='__main__':main()

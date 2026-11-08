#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build the own metadata reader externally; inspect originals without executing them."""
from pathlib import Path
import subprocess,sys,json
out=Path('/private/tmp/trainerdock-terraria');out.mkdir(exist_ok=True)
source=Path(__file__).with_suffix('.cs');dll=out/'InspectAssembly.dll'
sdk=subprocess.check_output(['dotnet','--list-sdks'],text=True).splitlines()[-1]
base=Path(sdk.split('[',1)[1].rstrip(']'));version=sdk.split()[0]
packs=base.parent/'packs/Microsoft.NETCore.App.Ref';ref=sorted(packs.iterdir(),key=lambda p:tuple(map(int,p.name.split('.'))))[-1];framework='net'+'.'.join(ref.name.split('.')[:2])
if not dll.exists() or source.stat().st_mtime>dll.stat().st_mtime:
 subprocess.run(['dotnet',str(base/version/'Roslyn/bincore/csc.dll'),'-nologo','-noconfig','-nostdlib+','-target:exe','-out:'+str(dll),*['-r:'+str(p) for p in (ref/'ref'/framework).glob('*.dll')],str(source)],check=True)
 dll.with_suffix('.runtimeconfig.json').write_text(json.dumps({'runtimeOptions':{'tfm':framework,'framework':{'name':'Microsoft.NETCore.App','version':ref.name}}}))
subprocess.run(['dotnet',str(dll),*sys.argv[1:]],check=True)

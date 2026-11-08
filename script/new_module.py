#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Create an inactive trainer source module; never build, install or launch it."""
import argparse
import copy
import json
from pathlib import Path
import re
import shutil
import uuid

ROOT=Path(__file__).resolve().parent.parent

def create_module(identifier,name,store,template='trainer',profile_path=None,output_root=None):
    if not all(re.fullmatch(r'[A-Za-z0-9_-]+',value) for value in (identifier,template)):
        raise ValueError('Invalid module ID or template name.')
    if not name.strip() or not store.strip():raise ValueError('Name and store must not be empty.')
    base=ROOT/'Templates/Trainer' if template=='trainer' else ROOT/'Modules'/template
    if not (base/'Build.json').is_file():raise ValueError('Module template not found.')
    config=copy.deepcopy(json.loads((base/'Build.json').read_text()))
    source=(base/config.get('sourceRoot','Sources')).resolve()
    if not any(allowed in source.parents for allowed in (ROOT/'Modules',ROOT/'Templates')):
        raise ValueError('Invalid template source path.')
    if profile_path:
        profile=json.loads(Path(profile_path).read_text())
        if not isinstance(profile,dict):raise ValueError('Profile must be a JSON object.')
        for key in ('id','name','bundleIdentifier','executable','version','teamIdentifier'):
            if not isinstance(profile.get(key),str) or not profile[key]:raise ValueError(f'Missing profile field: {key}')
        if not isinstance(profile.get('uuids'),list) or not profile['uuids']:raise ValueError('Missing UUID list.')
        for value in profile['uuids']:
            if not isinstance(value,str):raise ValueError('UUIDs must be strings.')
            uuid.UUID(value)
    else:
        profile=copy.deepcopy(json.loads((ROOT/'Templates/Trainer/Module.json').read_text())['profiles'][0])
        profile.update(id=identifier+'-macos',name=name+' · '+store)
    profile.update(enabled=False,store=store)
    if 'steamAppId' in profile:
        app_id=str(profile['steamAppId'])
        if not app_id.isdigit():raise ValueError('steamAppId must contain only digits.')
        profile['launchEnvironment']={'SteamAppId':app_id,'SteamGameId':app_id}
    config.update(sourceRoot='Sources',developmentOnly=True)
    module=dict(schemaVersion=1,id=identifier,name=name,version='0.1.0',profiles=[profile])
    overlay=(source/'Overlay.m').read_text()
    title_pattern=r'^static NSString \*gameTitle\(void\) \{ return [^\n]+; \}$'
    overlay,count=re.subn(title_pattern,lambda _: 'static NSString *gameTitle(void) { return @'+json.dumps(name,ensure_ascii=False)+'; }',overlay,flags=re.M)
    if count!=1:raise ValueError('Template needs exactly one gameTitle declaration for the trainer heading.')
    target=(Path(output_root) if output_root else ROOT/'Modules')/identifier
    target.mkdir()  # Never overwrite any existing source or module.
    shutil.copytree(source,target/'Sources')
    (target/'Sources/Overlay.m').write_text(overlay)
    for file in ('AGENTS.md','README.md','CHAT_START.md'):
        shutil.copyfile(ROOT/'Templates/Trainer'/file,target/file)
    (target/'Module.json').write_text(json.dumps(module,ensure_ascii=False,indent=2)+'\n')
    (target/'Build.json').write_text(json.dumps(config,indent=2)+'\n')
    return target

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--id',required=True)
    parser.add_argument('--name',required=True)
    parser.add_argument('--template',default='trainer',help='Neutral trainer template (default) or an existing module ID')
    parser.add_argument('--store',required=True)
    parser.add_argument('--profile',type=Path,help='Optional verified original identity; omitted fields remain empty without this file')
    args=parser.parse_args()
    try:target=create_module(args.id,args.name,args.store,args.template,args.profile)
    except (ValueError,OSError) as error:parser.exit(2,f'{error}\n')
    print(f'Deaktiviertes Entwicklungsmodul angelegt: {target}. Native Anbindung implementieren; developmentOnly und Profilfreigabe bleiben bis dahin gesperrt.')
if __name__=='__main__':main()

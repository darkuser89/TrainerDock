#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Real signed synthetic files; no installed game or trainer runtime is executed."""
import copy, hashlib, json, plistlib, re, stat, subprocess, tempfile, zipfile, warnings
warnings.filterwarnings("ignore", message="Duplicate name:", category=UserWarning)
from pathlib import Path
from BuildTools import ROOT, compile_tool

def run(*args):
 result=subprocess.run([str(a) for a in args],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 if result.returncode:raise RuntimeError(result.stdout.decode(errors='replace'))
 return result.stdout
def digest(data):return hashlib.sha256(data).hexdigest()
def write_json(path,value):path.write_text(json.dumps(value))

def main():
 with tempfile.TemporaryDirectory(prefix='TrainerDock-distribution-',dir='/private/tmp') as temporary:
  base=Path(temporary);identifier='fixture-'+base.name.rsplit('-',1)[-1].lower()
  code=base/'Fixture.c';code.write_text('int fixture_value(void){return 3;}\n')
  dylib=base/'Fixture.dylib';run('xcrun','clang','-arch','arm64','-mmacosx-version-min=27.0','-dynamiclib',code,'-o',dylib);run('codesign','--force','--sign','-',dylib)
  profiles=[]
  for index,label in enumerate(['Old','New']):
   app=base/(label+'Game.app');mac=app/'Contents/MacOS';mac.mkdir(parents=True)
   code.write_text('int main(void){return '+str(index)+';}\n');run('xcrun','clang','-arch','arm64','-mmacosx-version-min=27.0',code,'-o',mac/'Game')
   (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.trainerdock.fixture.game','CFBundleExecutable':'Game','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','CFBundlePackageType':'APPL'}));run('codesign','--force','--sign','-',app)
   uuid=re.search(r'UUID: ([0-9A-F-]+)',run('xcrun','dwarfdump','--uuid',mac/'Game').decode())[1]
   profiles.append({'id':'steam-'+label.lower()+'.1.0','name':'Steam-Test','store':'Steam','enabled':True,'bundleIdentifier':'local.trainerdock.fixture.game','executable':'Game','uuids':[uuid],'version':'1.0','architecture':'arm64'})
  def files(version,profile=None):
   manifest={'schemaVersion':1,'moduleABI':1,'id':identifier,'name':'Testtrainer','version':version,'profiles':[profile or profiles[1]],'features':[{'id':0,'title':'Testfunktion','binding':'fixture','shortcut':'F1','detail':'Nur synthetischer Test','implemented':False,'numeric':False,'oneShot':False,'integer':False,'initial':0,'minimum':0,'maximum':0,'step':0}]}
   config={'schemaVersion':1,'app':{'name':'Testtrainer','bundleIdentifier':'local.mht.module.'+identifier,'version':version,'build':'1'},'profiles':manifest['profiles']}
   return manifest,{'Module.json':json.dumps(manifest).encode(),'TrainerConfig.json':json.dumps(config).encode(),'Trainer.dylib':dylib.read_bytes(),'LICENSE':b'Synthetic fixture only\n'}
  def package(name,version,profile=None,mutate=None):
   manifest,contents=files(version,profile)
   if mutate:mutate(contents)
   path=base/name
   with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as archive:
    for key,data in contents.items():
     if key=='SYMLINK':
      info=zipfile.ZipInfo(identifier+'.mhtmodule/LICENSE');info.create_system=3;info.external_attr=(stat.S_IFLNK|0o777)<<16;archive.writestr(info,b'/private/tmp/escape');continue
     if key=='DUPLICATE':archive.writestr(identifier+'.mhtmodule/Module.json',data);continue
     archive.writestr(key if key.startswith(('../','/')) else identifier+'.mhtmodule/'+key,data)
   data=path.read_bytes();entry={'version':version,'fingerprint':digest(data),'url':f'https://github.com/darkuser89/TrainerDock/releases/download/trainer-{identifier}-v{version}/{identifier}-{version}.zip','sha256':digest(data),'size':len(data),'minimumLauncherVersion':'1.0.0','moduleABI':1,'manifest':manifest}
   return entry
  old=package('old.zip','1.0.0',profiles[0]);new=package('new.zip','1.0.1')
  catalog={'schemaVersion':1,'moduleABI':1,'modules':[{'id':identifier,'name':'Testtrainer','versions':[old,new]}]};write_json(base/'Catalog.json',catalog)
  legacy=base/'Legacy'/(identifier+'.mhtmodule');legacy.mkdir(parents=True);_,contents=files('1.0.1');contents['LICENSE']+=b'Legacy copy\n'
  for name,data in contents.items():(legacy/name).write_bytes(data)
  def alter_signed(contents):
   value=bytearray(contents['Trainer.dylib']);value[4096]^=1;contents['Trainer.dylib']=bytes(value)
  mutations=[lambda c:c.update({'../escape':b'escape'}),lambda c:c.update({'/absolute':b'escape'}),lambda c:c.update({'sub\\escape':b'escape'}),lambda c:c.update({'Extra.txt':b'extra'}),lambda c:c.pop('LICENSE'),lambda c:c.update({'LICENSE':b''}),lambda c:(c.pop('LICENSE'),c.update({'SYMLINK':b''})),lambda c:c.update({'DUPLICATE':c['Module.json']}),alter_signed,lambda c:c.update({'TrainerConfig.json':b'{}'})]
  bad_archives=[]
  for index,mutate in enumerate(mutations):
   filename=f'bad-{index}.zip';entry=package(filename,'1.0.'+str(index+2),mutate=mutate);bad_archives.append({'file':filename,'entry':entry})
  bad_profile=copy.deepcopy(profiles[1]);bad_profile['architecture']='x86_64';entry=package('bad-arch.zip','1.1.0',profile=bad_profile);bad_archives.append({'file':'bad-arch.zip','entry':entry})
  old_runtime=base/'OldRuntime.dylib';run('xcrun','clang','-arch','arm64','-mmacosx-version-min=26.0','-dynamiclib',code,'-o',old_runtime);run('codesign','--force','--sign','-',old_runtime)
  entry=package('bad-os.zip','1.1.1',mutate=lambda c:c.update({'Trainer.dylib':old_runtime.read_bytes()}));bad_archives.append({'file':'bad-os.zip','entry':entry})
  entry=copy.deepcopy(new);entry['sha256']='0'*64;bad_archives.append({'file':'new.zip','entry':entry})
  bad_catalogs=[]
  for mutate in [lambda c:c.update({'moduleABI':2}),lambda c:c['modules'][0]['versions'].append(copy.deepcopy(old)),lambda c:c['modules'][0]['versions'][0].update({'url':'https://github.com/other/repo/file.zip'}),lambda c:c['modules'][0]['versions'][0].update({'version':'1.0.0\n'}),lambda c:c['modules'][0]['versions'][0].update({'sha256':'z'*64}),lambda c:c['modules'][0]['versions'][0]['manifest']['profiles'][0].update({'name':12}),lambda c:c['modules'][0]['versions'][0]['manifest'].update({'id':'wrong'}),lambda c:c['modules'][0]['versions'][0]['manifest']['profiles'][0].update({'enabled':None}),lambda c:c['modules'][0]['versions'][0]['manifest']['features'][0].update({'numeric':True,'minimum':None})]:
   invalid=copy.deepcopy(catalog);mutate(invalid);bad_catalogs.append(invalid)
  metadata=copy.deepcopy(catalog)
  for entry in metadata['modules'][0]['versions']:
   for key in ['url','sha256','size','fingerprint']:entry.pop(key)
  write_json(base/'MetadataOnly.json',metadata);write_json(base/'Fixtures.json',{'id':identifier,'catalog':catalog,'badArchives':bad_archives,'badCatalogs':bad_catalogs,'metadataOnly':metadata})
  executable=base/'StoreTests';compile_tool('Tests/TrainerDistribution/StoreTests.m',executable)
  print(run(executable,base).decode().strip())
if __name__=='__main__':main()

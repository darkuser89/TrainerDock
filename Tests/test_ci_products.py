# SPDX-License-Identifier: GPL-3.0-only
"""Cross-job contracts using isolated test-only bytes; never publish/build games."""
import copy
import hashlib
import io
import json
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'script'))
import ci_products as ci
import trainer_distribution as dist


class ProductJobsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='trainerdock-ci-contract-')
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.root = self.base/'Build'
        self.source = self.base/'Source'
        self.directory = self.root/'Distribution/Trainers'
        self.directory.mkdir(parents=True)
        self.previous = dist.empty_catalog()
        self.item = dict(id='one', name='One', version='1.0.1', fingerprint='a'*64, contentFingerprint='b'*64)
        self.plan = dict(schemaVersion=1, modules=[self.item], launcher=dict(changed=False),
                         allModules=['one', 'two'], baselineSHA256=ci.digest(self.previous))
        self.context = dict(schemaVersion=1, commit='c'*40, planSHA256=ci.digest(self.plan),
                            baselineSHA256=ci.digest(self.previous), launcherVersion='')
        self.manifest = dict(schemaVersion=1, moduleABI=1, id='one', name='One', version='1.0.0', profiles=[dict(id='steam')])
        dist.write_json(self.source/'Modules/one/Module.json', self.manifest)
        dist.write_json(self.source/'Modules/one/Build.json', {'sourceRoot':'Sources'})
        (self.source/'Modules/one/Sources').mkdir()
        (self.source/'Modules/one/Sources/LICENSE').write_bytes(b'Test fixture')
        self.contents = {'Module.json': dist.json_bytes(dict(self.manifest, version='1.0.1', features=[dict(id=0)])),
                         'TrainerConfig.json': dist.json_bytes(dict(schemaVersion=1,app=dict(name='One',bundleIdentifier='local.mht.module.one',version='1.0.1',build='1'), profiles=self.manifest['profiles'])),
                         'Trainer.dylib': b'Explicit test-only bytes, never a product runtime', 'LICENSE': b'Test fixture'}
        self.source_patch = patch.object(ci, 'ROOT', self.source)
        self.source_patch.start(); self.addCleanup(self.source_patch.stop)

    def trainer(self, change=None):
        contents = dict(self.contents)
        if change:
            change(contents)
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, 'w') as archive:
            for name, data in contents.items():
                entry = zipfile.ZipInfo('one.mhtmodule/'+name)
                entry.external_attr = (stat.S_IFREG | 0o644) << 16
                archive.writestr(entry, data)
        data = stream.getvalue()
        record = dict(version='1.0.1', fingerprint='a'*64, contentFingerprint='b'*64,
                      url=dist.BASE_URL+'trainer-one-v1.0.1/one-1.0.1.zip', sha256=hashlib.sha256(data).hexdigest(),
                      size=len(data), minimumLauncherVersion='1.0.0', moduleABI=1,
                      manifest=json.loads(contents['Module.json']))
        (self.directory/'one-1.0.1.zip').write_bytes(data)
        dist.write_json(self.directory/'one-1.0.1.json', record)
        dist.write_json(self.directory/'one-1.0.1.build.json', dict(context=self.context,
                        fingerprint='a'*64, sha256=hashlib.sha256(self.contents['Trainer.dylib']).hexdigest(),recordSHA256=ci.digest(record)))
        return record

    def records(self):
        return ci.trainer_records(self.root, self.plan, self.context)

    def test_each_planned_trainer_is_independent_and_bound_to_final_bytes(self):
        record = self.trainer()
        self.assertEqual(self.records(), {'one': record})
        with self.assertRaises(ValueError):
            ci.module_item(self.plan, 'two')  # Unchanged requested ID is never forced into the matrix.
        self.trainer(lambda c:c.update({'Trainer.dylib':b'Replaced fixture bytes'}))
        with self.assertRaises(ValueError):self.records()

    def test_scope_never_discards_changed_shared_dependents_or_forces_versions(self):
        ci.validate_scope(self.plan, 'auto', '')
        ci.validate_scope(self.plan, 'trainers', 'one,two')
        ci.validate_scope(dict(self.plan, modules=[]), 'trainers', 'two')
        for mode, ids in [('launcher',''), ('trainers','two'), ('trainers','unknown'), ('auto','one'), ('trainers','one;bad')]:
            with self.subTest(mode=mode, ids=ids), self.assertRaises(ValueError):
                ci.validate_scope(self.plan, mode, ids)
        coupled = dict(self.plan, launcher=dict(changed=True))
        with self.assertRaises(ValueError):ci.validate_scope(coupled, 'trainers', 'one')

    def test_missing_extra_or_mixed_artifacts_abort_before_any_publication(self):
        self.trainer()
        proof = ci.read_json(self.directory/'one-1.0.1.build.json')
        proof['context'] = dict(self.context, commit='d'*40)
        dist.write_json(self.directory/'one-1.0.1.build.json', proof)
        with self.assertRaises(ValueError):self.records()
        self.trainer();(self.directory/'two-1.0.1.json').write_text('{}')
        with self.assertRaises(ValueError):self.records()
        (self.directory/'two-1.0.1.json').unlink();(self.directory/'one-1.0.1.build.json').unlink()
        with self.assertRaises(ValueError):self.records()

    def test_archive_cannot_hide_extra_profiles_or_paths(self):
        for change in [lambda c:c.update({'../escape':b'escape'}),
                       lambda c:c.update({'TrainerConfig.json':dist.json_bytes(dict(app=dict(version='1.0.1'), profiles=[dict(id='other')]))}),
                       lambda c:c.update({'extra.txt':b'extra'}),
                       lambda c:c.update({'LICENSE':b'Changed fixture license'})]:
            with self.subTest(change=change):
                self.trainer(change)
                with self.assertRaises(ValueError):self.records()
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as archive:
            entry=zipfile.ZipInfo('one.mhtmodule/LICENSE');entry.external_attr=(stat.S_IFLNK|0o777)<<16
            archive.writestr(entry,b'/private/tmp/foreign')
        with zipfile.ZipFile(io.BytesIO(stream.getvalue())) as archive:
            with self.assertRaises(ValueError):ci.archive_members(archive,'one.mhtmodule/')

    def test_plan_context_rejects_changed_commit_baseline_or_sources(self):
        for name, value in [('baseline.json',self.previous),('plan.json',self.plan),('ci-context.json',self.context)]:
            dist.write_json(self.root/'Distribution'/name,value)
        with patch.object(ci,'git_commit',return_value='c'*40), patch.object(dist,'module_fingerprint',return_value='a'*64), patch.object(dist,'module_content_fingerprint',return_value='b'*64):
            ci.read_state(self.root)
            changed=copy.deepcopy(self.context);changed['commit']='d'*40
            dist.write_json(self.root/'Distribution/ci-context.json',changed)
            with self.assertRaises(ValueError):ci.read_state(self.root)
            dist.write_json(self.root/'Distribution/ci-context.json',self.context)
            altered=copy.deepcopy(self.previous);altered['unexpected']='changed'
            dist.write_json(self.root/'Distribution/baseline.json',altered)
            with self.assertRaises(ValueError):ci.read_state(self.root)
            dist.write_json(self.root/'Distribution/baseline.json',self.previous)
            with patch.object(dist,'module_fingerprint',return_value='d'*64):
                with self.assertRaises(ValueError):ci.read_state(self.root)

    def test_build_commands_are_exact_and_unchanged_products_never_build(self):
        with patch.object(ci,'read_state',return_value=(self.previous,self.plan,self.context)), patch.object(ci,'run') as run:
            with self.assertRaises(ValueError):ci.build_trainer(self.root,'two')
            with self.assertRaises(ValueError):ci.build_launcher(self.root)
            run.assert_not_called()

    def test_matrix_job_builds_only_its_planned_module_and_keeps_final_receipt(self):
        self.trainer()
        dist.write_json(self.root/'BuildFingerprints/one.json',dict(fingerprint='a'*64,sha256='d'*64))
        with patch.object(ci,'read_state',return_value=(self.previous,self.plan,self.context)), patch.object(ci,'managed_input') as managed, patch.object(ci,'run') as run, patch.object(ci,'performance') as performance, patch.object(ci.subprocess,'run'), patch.object(dist,'package_module',return_value={'test':'record'}) as package:
            ci.build_trainer(self.root,'one')
            command=run.call_args.args
            self.assertEqual(command[0:3],('script/build.py','--module','one'))
            self.assertIn('Release',command);self.assertNotIn('--launcher-only',command)
            managed.assert_called_once_with('one');performance.assert_called_once_with('one')
            package.assert_called_once_with(self.root,self.item)
        proof=ci.read_json(self.directory/'one-1.0.1.build.json')
        self.assertEqual(proof,dict(context=self.context,fingerprint='a'*64,sha256='d'*64,recordSHA256=ci.digest({'test':'record'})))

    def test_publisher_validates_every_artifact_before_writing(self):
        self.trainer();(self.directory/'one-1.0.1.build.json').unlink()
        with patch.object(ci,'read_state',return_value=(self.previous,self.plan,self.context)), patch.object(dist,'GitHub') as github:
            with self.assertRaises(ValueError):ci.publish_trainers(self.root)
            github.assert_not_called()
        self.trainer()
        with patch.object(ci,'read_state',return_value=(self.previous,self.plan,self.context)), patch.object(ci,'may_publish',return_value=True), patch.object(dist,'GitHub') as github:
            github.return_value.publish_trainers.return_value=self.previous
            ci.publish_trainers(self.root)
            self.assertEqual(github.call_args.args[1],self.context['commit'])
            self.assertEqual(set(github.return_value.publish_trainers.call_args.args[1]),{'one'})

    def test_pull_requests_and_other_branches_cannot_publish(self):
        for event, ref, allowed in [('push','refs/heads/main',True),('push','refs/tags/v1.2.9',True),
                                     ('pull_request','refs/heads/main',False),('workflow_dispatch','refs/heads/topic',False),
                                     ('push','refs/tags/vbad',False)]:
            with self.subTest(event=event,ref=ref),patch.dict(ci.os.environ,{'GITHUB_EVENT_NAME':event,'GITHUB_REF':ref}):
                self.assertEqual(ci.may_publish(),allowed)

    def launcher(self):
        self.plan['modules']=[];self.plan['launcher']=dict(changed=True,fingerprint='e'*64,contentFingerprint='f'*64)
        self.context.update(planSHA256=ci.digest(self.plan),launcherVersion='1.2.9')
        info=dict(CFBundleShortVersionString='1.2.9',LSMinimumSystemVersion='27.0')
        build=dict(commit=self.context['commit'],version='1.2.9',architecture='arm64',modules=[],moduleABI=1)
        files={'Info.plist':plistlib.dumps(info),'Resources/BUILD.json':dist.json_bytes(build),
               'Resources/TrainerCatalog.json':dist.json_bytes(self.previous),
               'MacOS/TrainerDock':b'test-only','MacOS/TrainerDockEpicBroker':b'test-only','_CodeSignature/CodeResources':b'test-only'}
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as archive:
            for name,data in files.items():archive.writestr('TrainerDock.app/Contents/'+name,data)
        data=stream.getvalue();record=dict(version='1.2.9',size=len(data),sha256=hashlib.sha256(data).hexdigest())
        (self.root/'Distribution/TrainerDock-macOS-arm64.zip').write_bytes(data)
        dist.write_json(self.root/'Distribution/launcher-record.json',record)
        dist.write_json(self.root/'Distribution/launcher-build.json',dict(context=self.context,record=record,
            fingerprint='e'*64,contentFingerprint='f'*64,catalogSHA256=ci.digest(self.previous)))
        (self.root/'Distribution/SHA256SUMS').write_text(record['sha256']+'  TrainerDock-macOS-arm64.zip\n')

    def test_app_artifact_is_bound_to_its_commit_and_confirmed_catalog(self):
        self.launcher();ci.validate_launcher(self.root,self.plan,self.context,self.previous)
        with self.assertRaises(ValueError):ci.validate_launcher(self.root,self.plan,dict(self.context,commit='d'*40),self.previous)
        changed=dict(self.previous,unconfirmed=True)
        with self.assertRaises(ValueError):ci.validate_launcher(self.root,self.plan,self.context,changed)
        (self.root/'Distribution/SHA256SUMS').write_text('wrong checksum')
        with self.assertRaises(ValueError):ci.validate_launcher(self.root,self.plan,self.context,self.previous)

    def test_app_publish_refuses_a_stale_catalog_before_remote_writes(self):
        self.launcher()
        dist.write_json(self.root/'Catalog/catalog.json',self.previous)
        changed=dict(self.previous,unconfirmed=True)
        with patch.object(ci,'read_state',return_value=(self.previous,self.plan,self.context)),patch.object(ci,'may_publish',return_value=True),patch.object(dist,'fetch_catalog',return_value=changed),patch.object(ci,'run') as run:
            with self.assertRaises(ValueError):ci.publish_launcher(self.root)
            run.assert_not_called()

    def test_pr_app_uses_only_confirmed_catalog_and_read_only_build(self):
        self.launcher()
        with patch.object(ci,'read_state',return_value=(self.previous,self.plan,self.context)),patch.object(ci,'may_publish',return_value=False),patch.object(ci,'run') as run,patch.object(ci.subprocess,'run'):
            ci.build_launcher(self.root)
            self.assertEqual(dist.read_catalog(self.root/'Catalog/catalog.json'),self.previous)
            command=run.call_args_list[0].args
            self.assertIn('--launcher-only',command);self.assertNotIn('--module',command)
            self.assertEqual(run.call_args_list[-1].args[0],'script/release.py')


class WorkflowTopologyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        data=subprocess.check_output(['ruby','-ryaml','-rjson','-e','puts JSON.generate(YAML.load_file(ARGV[0]))',str(ROOT/'.github/workflows/build-release.yml')])
        cls.workflow=json.loads(data);cls.jobs=cls.workflow['jobs']

    def test_jobs_separate_products_and_serialize_catalog_writers(self):
        self.assertEqual(set(self.jobs),{'plan','contracts','build_trainers','publish_trainers','build_launcher','publish_launcher'})
        matrix=self.jobs['build_trainers']['strategy']
        self.assertIs(matrix['fail-fast'],False);self.assertEqual(matrix['max-parallel'],3)
        self.assertIn('outputs.modules',matrix['matrix']['module'])
        self.assertIn('publish_trainers',self.jobs['build_launcher']['needs'])
        self.assertIn('build_launcher',self.jobs['publish_launcher']['needs'])
        for name,job in self.jobs.items():
            self.assertEqual(job.get('permissions',self.workflow['permissions'])['contents'],'write' if name.startswith('publish_') else 'read')
            if name.startswith('publish_'):
                self.assertIn("github.event_name != 'pull_request'",job['if'])
                self.assertIn("needs.plan.result == 'success'",job['if'])
        self.assertIn('always()',self.jobs['build_launcher']['if'])
        self.assertIn("needs.plan.outputs.launcher_changed == 'true'",self.jobs['build_launcher']['if'])
        self.assertIn("needs.plan.outputs.modules != '[]'",self.jobs['build_trainers']['if'])

    def test_all_actions_are_immutable_and_artifacts_have_bounded_retention(self):
        for job in self.jobs.values():
            for step in job['steps']:
                if 'uses' in step:self.assertRegex(step['uses'],r'^[a-z0-9-]+/[a-z0-9-]+@[0-9a-f]{40}$')
                if step.get('uses','').startswith('actions/upload-artifact@'):
                    self.assertEqual(step['with']['retention-days'],7)
                    self.assertEqual(step['with']['if-no-files-found'],'error')
        self.assertIn('publication',self.workflow['concurrency']['group'])


if __name__=='__main__':unittest.main()

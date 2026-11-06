# SPDX-License-Identifier: GPL-3.0-only
"""Verify generated modules stay inactive and contain no inherited native bindings."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('new_module',ROOT/'script/new_module.py')
generator=importlib.util.module_from_spec(spec);spec.loader.exec_module(generator)

class TemplateTests(unittest.TestCase):
    def test_neutral_module_is_an_inactive_development_source(self):
        with tempfile.TemporaryDirectory(prefix='mht-template-') as temp:
            target=generator.create_module('new-game','Neues Spiel','Steam',output_root=temp)
            config=json.loads((target/'Build.json').read_text());module=json.loads((target/'Module.json').read_text())
            self.assertTrue(config['developmentOnly']);self.assertFalse(module['profiles'][0]['enabled'])
            self.assertEqual(module['profiles'][0]['uuids'],[])
            self.assertEqual(module['profiles'][0]['bundleIdentifier'],'')
            for source in config['sources']:self.assertTrue((target/'Sources'/source).is_file())
            self.assertTrue((target/'Sources/NativeAdapter.m').is_file())
            self.assertTrue((target/'AGENTS.md').is_file())
            self.assertFalse(any(target.rglob('*Bindings*')))
            self.assertFalse(any(target.rglob('*.dylib')))
            with self.assertRaises(FileExistsError):
                generator.create_module('new-game','Another game','Steam',output_root=temp)
            self.assertEqual(json.loads((target/'Module.json').read_text())['name'],'Neues Spiel')

    def test_provided_enabled_profile_is_always_deactivated(self):
        with tempfile.TemporaryDirectory(prefix='mht-template-') as temp:
            profile=json.loads((ROOT/'Modules/robocop/Module.json').read_text())['profiles'][0]
            data=Path(temp)/'profile.json';data.write_text(json.dumps(profile))
            target=generator.create_module('variant','Variante','Steam',profile_path=data,output_root=temp)
            created=json.loads((target/'Module.json').read_text())['profiles'][0]
            self.assertFalse(created['enabled']);self.assertEqual(created['uuids'],profile['uuids'])
            self.assertEqual(created['launchEnvironment']['SteamAppId'],profile['steamAppId'])
            self.assertTrue(json.loads((target/'Build.json').read_text())['developmentOnly'])

    def test_invalid_input_writes_nothing(self):
        with tempfile.TemporaryDirectory(prefix='mht-template-') as temp:
            with self.assertRaises(ValueError):generator.create_module('../escape','Spiel','Steam',output_root=temp)
            data=Path(temp)/'invalid.json';data.write_text('{}')
            with self.assertRaises(ValueError):generator.create_module('invalid','Spiel','Steam',profile_path=data,output_root=temp)
            self.assertFalse((Path(temp)/'invalid').exists())

if __name__=='__main__':unittest.main()

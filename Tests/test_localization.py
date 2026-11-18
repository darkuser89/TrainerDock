# SPDX-License-Identifier: GPL-3.0-only
"""Validate shipped launcher resources and format contracts; no app/game starts."""
import collections
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PAIR = re.compile(r'^("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");$', re.M)
FORMAT = re.compile(r'%(?:\d+\$)?[-+#0 ]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|[hlLzjtq])?[@diuoxXfFeEgGaAcCsSp%]')


class LocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tables = {}
        for language in ('de', 'en', 'ro'):
            text = (ROOT / f'App/Resources/{language}.lproj/Localizable.strings').read_text()
            pairs = [(json.loads(k), json.loads(v)) for k, v in PAIR.findall(text)]
            if len(pairs) != len(dict(pairs)):
                raise AssertionError(f'Duplicate localization key: {language}')
            cls.tables[language] = dict(pairs)

    def test_all_languages_have_the_same_nonempty_strings(self):
        reference = set(self.tables['de'])
        self.assertGreater(len(reference), 300)
        for language, table in self.tables.items():
            self.assertEqual(set(table), reference, language)
            self.assertTrue(all(table.values()), language)

    def test_translations_preserve_native_format_arguments(self):
        for language, table in self.tables.items():
            for key, value in table.items():
                self.assertEqual(collections.Counter(FORMAT.findall(key)),
                                 collections.Counter(FORMAT.findall(value)), (language, key))

    def test_all_literal_host_lookups_are_translated(self):
        lookup = re.compile(r'MHTLocalized\(@("(?:[^"\\]|\\.)*")\)')
        keys = set()
        for folder in ('App', 'Core'):
            for source in (ROOT / folder).glob('*.m'):
                keys.update(json.loads(k) for k in lookup.findall(source.read_text()))
        self.assertFalse(keys - self.tables['en'].keys())

    def test_native_bundle_declares_supported_languages_and_english_fallback(self):
        import plistlib
        info = plistlib.loads((ROOT / 'Config/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleLocalizations'], ['en', 'de', 'ro'])
        self.assertEqual(info['CFBundleDevelopmentRegion'], 'en')


if __name__ == '__main__':
    unittest.main()

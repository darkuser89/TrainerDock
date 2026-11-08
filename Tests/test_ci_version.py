# SPDX-License-Identifier: GPL-3.0-only
import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'script'))
from ci_version import choose_version


class ReleaseVersionTests(unittest.TestCase):
    def test_new_minor_floor(self):
        self.assertEqual(choose_version('1.2.0', 'branch', 'main', ['v1.1.0']), '1.2.0')

    def test_next_main_push_increments_patch(self):
        self.assertEqual(choose_version('1.2.0', 'branch', 'main', ['v1.2.0']), '1.2.1')

    def test_numeric_order_and_orphaned_tags(self):
        self.assertEqual(choose_version('1.2.0', 'branch', 'main', ['v1.2.9', 'v1.2.10', 'v1.2.11', 'v1.2.11^{}']), '1.2.12')

    def test_newer_remote_minor_is_not_downgraded(self):
        self.assertEqual(choose_version('1.2.0', 'branch', 'main', ['v2.1.8']), '2.1.9')

    def test_developer_tags_do_not_affect_versions(self):
        self.assertEqual(choose_version('1.2.0', 'branch', 'main', ['managed-inputs-v1', 'v9.0.0-beta']), '1.2.0')

    def test_explicit_release_tag(self):
        self.assertEqual(choose_version('1.2.0', 'tag', 'v2.3.4', ['v3.0.0']), '2.3.4')

    def test_pull_request_does_not_allocate_release(self):
        self.assertEqual(choose_version('1.2.0', 'branch', '48/merge', ['v1.2.0']), '1.2.0')

    def test_invalid_tag_is_rejected(self):
        for tag in ('v1.2', 'v1.02.3', 'v1.2.3-beta', 'hello'):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                choose_version('1.2.0', 'tag', tag, [])


if __name__ == '__main__':
    unittest.main()

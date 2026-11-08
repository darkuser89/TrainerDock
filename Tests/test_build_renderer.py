# SPDX-License-Identifier: GPL-3.0-only
"""Missing test hardware may be explicit; actual renderer failures remain fatal."""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "script"))
from build import run_renderer_check


class RendererExitPolicy(unittest.TestCase):
    def invoke(self, code, permission=None):
        env = {} if permission is None else {"TRAINERDOCK_ALLOW_MISSING_TEST_GPU": permission}
        with patch("build.subprocess.run", return_value=subprocess.CompletedProcess(["fixture"], code)):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                run_renderer_check(Path("fixture"), env)
            return output.getvalue()

    def test_success_needs_no_exception(self):
        self.assertEqual(self.invoke(0), "")

    def test_no_local_hardware_still_fails(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.invoke(77)

    def test_explicit_missing_hardware_is_not_a_pass(self):
        self.assertIn("NOT RUN", self.invoke(77, "1"))

    def test_real_failure_and_signal_cannot_be_skipped(self):
        for code in (1, 2, -6):
            with self.subTest(code=code), self.assertRaises(subprocess.CalledProcessError):
                self.invoke(code, "1")

    def test_permission_is_explicit(self):
        for permission in ("0", "true", ""):
            with self.subTest(permission=permission), self.assertRaises(subprocess.CalledProcessError):
                self.invoke(77, permission)


if __name__ == "__main__":
    unittest.main()

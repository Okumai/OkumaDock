"""Applications activation and saved-pin migration regression tests."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("launcher", ROOT / "activate-launcher.py")
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class ActivationTests(unittest.TestCase):
    def test_live_launchpad(self):
        for before, after in (("closed", "open"), ("open", "closed")):
            with patch.object(launcher, "ipc", side_effect=[before, "", after]) as ipc:
                self.assertEqual(launcher.activate(), launcher.LAUNCHPAD)
                self.assertEqual(ipc.call_args_list[1].args, ("toggle", launcher.LAUNCHPAD, "{}"))

    def test_missing_or_disabled_launchpad_falls_back(self):
        with patch.object(launcher, "ipc", side_effect=["unknown", "ok"]) as ipc:
            self.assertEqual(launcher.activate(), launcher.MENU)
            self.assertEqual(ipc.call_args.args, ("summon", launcher.MENU, '{"initialMenu":"apps"}'))

    def test_explicit_missing_launchpad_fails(self):
        with patch.object(launcher, "ipc", return_value="unknown") as ipc:
            with self.assertRaisesRegex(RuntimeError, "not loaded"):
                launcher.activate(launcher.LAUNCHPAD)
            self.assertEqual(ipc.call_count, 1)

    def test_noop_toggle_is_not_success(self):
        with patch.object(launcher, "ipc", return_value="closed"), patch.object(launcher.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "did not change state"):
                launcher.activate()

    def test_transport_error_never_opens_second_panel(self):
        with patch.object(launcher, "ipc", side_effect=RuntimeError("IPC failed")) as ipc:
            with self.assertRaises(RuntimeError):
                launcher.activate()
            self.assertEqual(ipc.call_count, 1)

    def test_pin_routing(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("node is needed to execute the shared JavaScript routing tests")
        cases = [
            ({"launcher": True}, True),
            ({"key": "apps", "shellPlugin": "omarchy.menu", "payload": {"menu": "apps"}}, True),
            ({"key": "apps", "command": ["omarchy-shell", "omarchy.dock", "apps"]}, True),
            ({"key": "system", "shellPlugin": "omarchy.menu", "payload": {"menu": "system"}}, False),
            ({"key": "launcher", "shellPlugin": "omarchy.menu", "payload": {"initialMenu": "apps"}}, True),
            ({"key": "launcher", "command": ["/home/other/.local/bin/launchpad", "toggle"]}, True),
            ({"key": "launchpad", "shellPlugin": launcher.LAUNCHPAD}, True),
            ({"key": "launcher", "command": ["custom-launcher"]}, False),
            ({"key": "browser", "command": ["chromium"]}, False),
            ({"key": "launcher", "shellPlugin": "omarchy.menu", "payload": {"initialMenu": "power"}}, False),
        ]
        script = (ROOT / "Launcher.js").read_text() + "\nconsole.log(JSON.stringify(" + json.dumps(cases) + ".map(c => commandFor(c[0], '/plugin/', 'auto'))));"
        result = subprocess.run([node, "-e", script], capture_output=True, text=True, check=True)
        for (pin, expected), command in zip(cases, json.loads(result.stdout)):
            with self.subTest(pin=pin):
                self.assertEqual(command is not None, expected)
                if command:
                    self.assertEqual(command[:2], ["python3", "/plugin/activate-launcher.py"])

    def test_strict_preference_and_explicit_launchpad_override(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("node is required")
        script = (ROOT / "Launcher.js").read_text() + '''
const strict = commandFor({launcher:true}, '/plugin/', 'okuma.dev_launchpad4omarchy');
const explicit = commandFor({shellPlugin:'okuma.dev_launchpad4omarchy'}, '/plugin/', 'omarchy.menu');
if (strict[3] !== 'okuma.dev_launchpad4omarchy' || explicit[3] !== strict[3]) process.exit(1);
'''
        subprocess.run([node, "-e", script], check=True)


if __name__ == "__main__":
    unittest.main()

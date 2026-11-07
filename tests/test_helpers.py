"""Portable helper regression tests; no running compositor is required."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('discovery', ROOT / 'discover-apps.py')
discovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(discovery)


class DiscoveryTests(unittest.TestCase):
    def test_plugin_identity(self):
        manifest = json.loads((ROOT / 'manifest.json').read_text())
        example = json.loads((ROOT / 'examples/plugin-settings.json').read_text())
        self.assertEqual(manifest['id'], 'okuma.dev_dock4omarchy')
        self.assertEqual(manifest['author'], '\u014cKUMA')
        self.assertEqual(example['id'], manifest['id'])
        self.assertIn('property string pluginId: "' + manifest['id'] + '"', (ROOT / 'Dock.qml').read_text())

    def test_executable(self):
        self.assertEqual(discovery.executable({'exec': 'env FLAG=yes /usr/bin/browser %U'}), 'browser')
        self.assertEqual(discovery.executable({'exec': '"unterminated'}), '')

    def test_classes_are_normalized(self):
        pin = discovery.make_pin({'Example': {'name': 'Example', 'startupwmclass': 'EXAMPLE', 'exec': 'example %U'}}, 'example', 'Example')
        self.assertEqual(pin['classes'], ['example'])

    def test_minimal_install_has_launcher(self):
        with patch.object(discovery, 'read_entries', return_value={}), patch.object(discovery, 'command_output', return_value=''), patch.object(discovery.shutil, 'which', return_value=None):
            pins = discovery.discover()
        self.assertEqual([p['key'] for p in pins], ['launcher'])
        self.assertEqual(pins[0]['shellPlugin'], 'omarchy.menu')

    def test_browser_uses_real_omarchy_default(self):
        entries = {'example-browser': {'name': 'Example Browser', 'exec': 'example-browser %U', 'icon': 'example-browser'}}
        def output(argv):
            return 'example-browser.desktop' if argv[0] == 'omarchy-cmd-default-browser' else ''
        with patch.object(discovery, 'read_entries', return_value=entries), patch.object(discovery, 'command_output', side_effect=output), patch.object(discovery.shutil, 'which', return_value=None):
            pins = discovery.discover()
        self.assertEqual(pins[0]['desktop'], 'example-browser')
        self.assertIn('example-browser', pins[0]['classes'])

    def test_xdg_desktop_precedence(self):
        with tempfile.TemporaryDirectory() as tmp:
            local, system = Path(tmp) / 'local', Path(tmp) / 'system'
            for root, name in [(local, 'Local'), (system, 'System')]:
                (root / 'applications').mkdir(parents=True)
                (root / 'applications/example.desktop').write_text('[Desktop Entry]\nName=' + name + '\nExec=example\n')
            with patch.dict(os.environ, XDG_DATA_HOME=str(local), XDG_DATA_DIRS=str(system)):
                self.assertEqual(discovery.read_entries()['example']['name'], 'Local')

    def test_repository_text_allows_only_author_unicode(self):
        for path in ROOT.rglob('*'):
            if path.is_file() and not any(p.startswith('.') or p == '__pycache__' for p in path.relative_to(ROOT).parts):
                with self.subTest(path=path):
                    text = path.read_text(encoding='utf-8')
                    # English source permits the branded author name with a macron.
                    text.replace('\u014cKUMA', 'OKUMA').encode('ascii')


if __name__ == '__main__':
    unittest.main()

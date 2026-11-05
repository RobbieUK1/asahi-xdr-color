"""Exercise install, repeat install, uninstall and rollback in a temporary home."""
import json, pathlib, tempfile, unittest
from unittest.mock import patch

SOURCE = (pathlib.Path(__file__).parent / 'install.sh').read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
SOURCE = SOURCE.split('\ntry:\n    main()')[0]

class InstallerTest(unittest.TestCase):
    def test_lifecycle_and_rollback(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as tmp:
                home = pathlib.Path(tmp)
                config = home / '.config/hypr/hyprland.lua'
                config.parent.mkdir(parents=True)
                original = 'require("hypr.omacontrol")\nrequire("default.hypr.toggles")\n'
                config.write_text(original)
                monitor = dict(name='eDP-1', width=3456, height=2234, refreshRate=120, x=9, y=10, scale=2, transform=0, vrr=True, colorManagementPreset='srgb', currentFormat='XRGB8888')
                calls = 0
                def run(*args):
                    nonlocal calls
                    if args[1] == 'version': return 'Hyprland 0.56.2'
                    if args[1] == 'configerrors': return ''
                    if args[1] == 'reload': return 'ok'
                    calls += 1
                    m = monitor.copy()
                    if calls > 1 and not fail:
                        m.update(colorManagementPreset='dp3', currentFormat='XRGB2101010')
                    return json.dumps([m])
                with patch('pathlib.Path.home', return_value=home), patch('os.geteuid', return_value=1000):
                    ns = {}; exec(compile(SOURCE, 'install.sh', 'exec'), ns)
                ns['run'] = run
                with patch.object(pathlib.Path, 'read_bytes', return_value=b'Apple MacBook Pro (16-inch, M1 Max, 2021)\0'), patch('sys.argv', ['install.sh']), patch('subprocess.run'):
                    if fail:
                        with self.assertRaises(RuntimeError): ns['main']()
                        self.assertEqual(config.read_text(), original)
                        self.assertFalse(ns['MODULE'].exists())
                    else:
                        ns['main']()
                        self.assertIn('position = "9x10"', ns['MODULE'].read_text())
                        ns['main']()
                        with patch('sys.argv', ['install.sh', '--uninstall']): ns['main']()
                        self.assertEqual(config.read_text(), original)
                        self.assertFalse(ns['MODULE'].exists())

if __name__ == '__main__': unittest.main()

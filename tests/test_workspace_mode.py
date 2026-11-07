"""Exercise the observer's actual JavaScript functions without a compositor."""
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("node"), "Node.js is needed to execute QML JavaScript")
class WorkspaceModeTests(unittest.TestCase):
    def test_observer_state_machine(self):
        source = (ROOT / "WorkspaceMode.qml").read_text()
        functions = "\n".join(re.findall(r"^    function .*?^    }", source, re.S | re.M))
        supported = re.search(r"readonly property bool supported: (.*)", source)[1]
        script = """
const assert = require('node:assert/strict');
let workspaceId = 1, mode = '', generation = 0, requestGeneration = -1;
let requestWorkspace = -1, pending = false, output = '';
const query = {running: false, command: []};
""" + functions + "\nconst supported = () => " + supported + ";\n" + """
assert.equal(supported(), false);
readMode();
assert.deepEqual(query.command, ['omarchy-hyprland-workspace-layout-current', '1']);
for (const value of ['dwindle', 'scrolling', 'floating', 'unknown', '']) {
    output = value + '\\n'; finishRead(0);
    assert.equal(supported(), ['dwindle', 'scrolling'].includes(value));
}
output = 'dwindle'; finishRead(1);
assert.equal(mode, '');
output = 'scrolling'; finishRead(0);
assert.equal(mode, 'scrolling');
workspaceId = 2; invalidate();
assert.equal(mode, '');
assert.equal(pending, true);
output = 'dwindle'; finishRead(0);
assert.equal(mode, '', 'old workspace result must not become visible');
query.running = false; readMode();
assert.equal(requestWorkspace, 2);
assert.equal(pending, false);
query.running = false; output = 'floating'; finishRead(0);
assert.equal(mode, 'floating');
readMode(); invalidate();
output = 'scrolling'; finishRead(0);
assert.equal(mode, '', 'pre-reload result must be discarded');
query.running = false; workspaceId = -99; readMode();
assert.equal(query.running, false, 'special workspaces are not queried');
"""
        subprocess.run(["node", "-e", script], check=True, capture_output=True, text=True)

    def test_panel_gating_and_no_system_ipc_override(self):
        source = (ROOT / "Dock.qml").read_text()
        self.assertIn("Hyprland.monitorFor(screen)", source)
        self.assertIn("visible: !root.barHidden && modeObserver.supported", source)
        self.assertIn("exclusionMode: visible ? ExclusionMode.Auto : ExclusionMode.Ignore", source)
        observer = (ROOT / "WorkspaceMode.qml").read_text()
        self.assertNotIn('target: "omarchy.dock"', observer)
        self.assertNotIn('target: "omarchy.workspaces"', observer)


if __name__ == "__main__":
    unittest.main()

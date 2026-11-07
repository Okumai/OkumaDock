import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

// Observe Omarchy's mode, not tiledLayout: floating retains its tiled layout.
// Do not claim omarchy.dock/omarchy.workspaces IPC targets owned by the shell.
Item {
    id: root
    required property int workspaceId
    property string mode: ""
    readonly property bool supported: mode === "dwindle" || mode === "scrolling"
    property int generation: 0
    property int requestGeneration: -1
    property int requestWorkspace: -1
    property bool pending: false
    property string output: ""

    function invalidate() {
        generation++;
        mode = "";
        readMode();
    }

    function readMode() {
        if (query.running) { pending = true; return; }
        if (workspaceId < 1) return;
        pending = false;
        output = "";
        requestWorkspace = workspaceId;
        requestGeneration = generation;
        query.command = ["omarchy-hyprland-workspace-layout-current", String(workspaceId)];
        query.running = true;
    }

    function finishRead(exitCode) {
        // A workspace switch or reload can overtake an asynchronous query.
        if (requestWorkspace !== workspaceId || requestGeneration !== generation) return;
        const value = output.trim();
        mode = exitCode === 0 && ["dwindle", "scrolling", "floating"].indexOf(value) !== -1 ? value : "";
    }

    onWorkspaceIdChanged: invalidate()
    Component.onCompleted: readMode()

    Process {
        id: query
        stdout: StdioCollector { onStreamFinished: root.output = text }
        onExited: (exitCode, exitStatus) => {
            root.finishRead(exitStatus === 0 ? exitCode : -1);
            if (root.pending) Qt.callLater(root.readMode);
        }
    }

    // Layout commands only refresh the built-in plugins via their private IPC.
    // Poll as well so same-workspace mode changes are noticed without hijacking
    // those targets or modifying system commands. Queries never overlap.
    Timer {
        interval: 750
        running: root.workspaceId >= 1
        repeat: true
        onTriggered: root.readMode()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event ? String(event.name) : "";
            if (name === "configreloaded") root.invalidate();
            if (["workspacev2", "moveworkspacev2", "changeworkspaceid", "monitoradded", "monitorremoved"].indexOf(name) !== -1) {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
            }
        }
    }
}

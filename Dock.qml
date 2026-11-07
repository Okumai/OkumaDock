import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons

Item {
    id: root
    property var shell: null
    readonly property string pluginId: "okuma.dev_dock4omarchy"
    readonly property string pluginDirectory: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, ""))
    readonly property int barHeight: shell && shell.bar && shell.bar.barSize > 0 ? shell.bar.barSize : Commons.Style.bar.sizeHorizontal
    readonly property bool barHidden: shell && shell.bar ? shell.bar.barHidden : false
    readonly property string barFont: shell && shell.bar ? shell.bar.fontFamily : Commons.Style.font.family
    property var settings: ({})
    property var pendingLaunches: ({})
    property var iconIndex: ({})
    readonly property string fallbackIcon: Qt.resolvedUrl("fallback-app.svg")
    Process {
        id: iconScan
        running: true
        command: ["python3", root.pluginDirectory + "index-icons.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.iconIndex = JSON.parse(text); }
                catch (e) { console.warn("Dock icon index:", e); }
            }
        }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { iconRefresh.restart(); }
    }
    Timer { id: iconRefresh; interval: 750; onTriggered: if (!iconScan.running) iconScan.running = true }

    function iconSource(value) {
        const name = String(value || "");
        if (!name) return fallbackIcon;
        if (name.startsWith("/") || name.startsWith("file:") || name.startsWith("image:"))
            return name.startsWith("/") ? "file://" + name : name;
        // Use a neutral grid that stays visible against both light and dark bars.
        if (name === "view-app-grid-symbolic") return Qt.resolvedUrl("launcher.svg");
        // Direct file lookup avoids Qt theme-provider failures during session startup.
        if (iconIndex[name]) return "file://" + iconIndex[name];
        return Quickshell.iconPath(name, true) || fallbackIcon;
    }
    property var defaults: []
    Process {
        id: defaultDiscovery
        running: true
        command: ["python3", root.pluginDirectory + "discover-apps.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.defaults = JSON.parse(text); }
                catch (e) { console.warn("OkumarchyDock application discovery:", e); }
            }
        }
    }
    readonly property var pinned: settings.pinned || defaults
    readonly property var windows: Hyprland.toplevels.values
    readonly property var apps: buildApps()

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const config = JSON.parse(text());
                root.settings = (config.plugins || []).find(p => p.id === root.pluginId) || {};
            } catch (e) { console.warn("Dock settings:", e); }
        }
    }

    signal menuRequested(string key)
    function showMenu(key) { menuRequested(key); return "ok"; }
    function activate(key) {
        const app = apps.find(a => a.key === key);
        if (!app) return "unknown";
        if (app.windows.length === 1) focusWindow(app.windows[0]);
        else if (app.windows.length > 1) menuRequested(key);
        else launch(app);
        return "ok";
    }
    function status() {
        return JSON.stringify({height: barHeight, hidden: barHidden, screens: dockWindows.instances.map(d => ({name: d.screen.name, workspace: d.workspaceId, mode: d.workspaceMode, visible: d.visible})), background: String(Commons.Color.bar.background), font: barFont, apps: apps.map(a => ({key: a.key, name: a.name, pinned: a.pinned, windows: a.windows.map(w => ({address: w.address, title: w.title, className: windowClass(w)}))}))});
    }
    function windowClass(w) { return String(w.lastIpcObject.class || (w.wayland ? w.wayland.appId : "")).toLowerCase(); }
    function matches(app, w) { return (app.classes || []).indexOf(windowClass(w)) !== -1; }
    function entryFor(id) { return id ? DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id) : null; }
    function buildApps() {
        // Depend on the application catalogue so late icon discovery updates the dock.
        const catalogue = DesktopEntries.applications.values;
        let result = pinned.map(p => Object.assign({}, p, {pinned: true, windows: []}));
        for (const w of windows) {
            const cls = windowClass(w);
            if (!cls || w.lastIpcObject.mapped === false) continue;
            let app = result.find(a => matches(a, w));
            if (!app) {
                const entry = entryFor(cls);
                const key = entry ? entry.id : cls;
                app = result.find(a => !a.pinned && a.key === key);
                if (!app) {
                    app = {key: key, name: entry ? entry.name : (w.title || cls), desktop: entry ? entry.id : "", icon: entry ? entry.icon : "application-x-executable", classes: [cls], windows: [], pinned: false};
                    result.push(app);
                }
            }
            app.windows.push(w);
        }
        const order = settings.runningOrder || [];
        const fixed = result.filter(a => a.pinned);
        const running = result.filter(a => !a.pinned);
        running.sort((a, b) => {
            const ai = order.indexOf(a.key), bi = order.indexOf(b.key);
            return (ai < 0 ? order.length : ai) - (bi < 0 ? order.length : bi);
        });
        return fixed.concat(running);
    }
    function reorder(sourceKey, targetKey, after) {
        const source = apps.find(a => a.key === sourceKey);
        const target = apps.find(a => a.key === targetKey);
        if (!shell || !source || !target || source.pinned !== target.pinned || sourceKey === targetKey) return false;
        const list = source.pinned ? pinned.slice() : apps.filter(a => !a.pinned).map(a => a.key);
        const keyOf = value => source.pinned ? value.key : value;
        const from = list.findIndex(value => keyOf(value) === sourceKey);
        const moved = list.splice(from, 1)[0];
        const to = list.findIndex(value => keyOf(value) === targetKey) + (after ? 1 : 0);
        list.splice(to, 0, moved);
        const patch = source.pinned ? {pinned: list} : {runningOrder: list};
        if (!shell.updateEntryInline(root.pluginId, patch)) return false;
        settings = Object.assign({}, settings, patch);
        return true;
    }
    function launch(app) {
        const now = Date.now();
        if (now - (pendingLaunches[app.key] || 0) < 2000) return;
        pendingLaunches = Object.assign({}, pendingLaunches, {[app.key]: now});
        // Panel-scoped APIs cannot toggle unrelated plugins; use the public shell IPC.
        if (app.shellPlugin) Quickshell.execDetached(["omarchy-shell", "shell", "toggle", app.shellPlugin, JSON.stringify(app.payload || {})]);
        else if (app.command && app.command.length) Quickshell.execDetached(app.command);
        else { const entry = entryFor(app.desktop); if (entry) entry.execute(); }
        launchReset.restart();
    }
    function focusWindow(w) {
        if (!w) return;
        const address = String(w.address).replace(/^0x/, "");
        if (!/^[0-9a-f]+$/i.test(address)) return;
        // Disable compositor cursor warping only for this focus operation.
        Quickshell.execDetached(["hyprctl", "eval", 'local old=hl.get_config("cursor.no_warps"); hl.config({cursor={no_warps=true}}); local ok,err=pcall(function() hl.dispatch(hl.dsp.focus({window="address:0x' + address + '"})) end); hl.config({cursor={no_warps=old}}); if not ok then error(err) end']);
    }
    function pin(app) {
        const next = pinned.slice();
        if (app.pinned) {
            const index = next.findIndex(a => a.key === app.key);
            if (index !== -1) next.splice(index, 1);
        } else {
            if (!app.desktop) return;
            next.push({key: app.key, name: app.name, desktop: app.desktop, icon: app.icon, classes: app.classes});
        }
        if (shell) shell.updateEntryInline(root.pluginId, {pinned: next});
    }
    Timer { id: launchReset; interval: 2200; onTriggered: root.pendingLaunches = ({}) }

    Variants {
        id: dockWindows
        model: Quickshell.screens
        PanelWindow {
            id: dock
            required property var modelData
            screen: modelData
            readonly property var monitor: Hyprland.monitorFor(screen)
            readonly property int workspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
            readonly property string workspaceMode: modeObserver.mode
            WorkspaceMode {
                id: modeObserver
                workspaceId: dock.workspaceId
            }
            anchors { left: true; right: true; bottom: true }
            implicitHeight: root.barHeight
            visible: !root.barHidden && modeObserver.supported
            onVisibleChanged: if (!visible) { menuOpen = false; tooltipReady = false; hoverItem = null; cancelDrag(); }
            color: root.shell && root.shell.barConfig.transparent ? "transparent" : Commons.Color.bar.background
            exclusionMode: visible ? ExclusionMode.Auto : ExclusionMode.Ignore
            WlrLayershell.namespace: "okumarchy-dock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            property var hoverItem: null
            property var menuItem: null
            property var menuApp: null
            property bool menuOpen: false
            property bool tooltipReady: false
            property string dragKey: ""
            property string dropKey: ""
            property bool dropAfter: false
            property real dragX: 0
            property string dragIcon: ""
            function cancelDrag() { dragKey = ""; dropKey = ""; }
            function updateDrag(source, point) {
                dragX = Math.max(viewport.x, Math.min(viewport.x + viewport.width, point.x));
                const edge = 16;
                if (point.x < viewport.x + edge) viewport.contentX = Math.max(0, viewport.contentX - 8);
                else if (point.x > viewport.x + viewport.width - edge) viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - viewport.width, viewport.contentX + 8));
                const local = icons.mapFromItem(dock.contentItem, point.x, point.y);
                dropKey = "";
                for (let i = 0; i < appRepeater.count; ++i) {
                    const item = appRepeater.itemAt(i);
                    if (!item || item.app.pinned !== source.pinned) continue;
                    if (local.x >= item.x && local.x <= item.x + item.width) {
                        dropKey = item.app.key;
                        dropAfter = local.x >= item.x + item.width / 2;
                        break;
                    }
                }
            }
            readonly property int slotWidth: Math.max(root.barHeight + 10, Commons.Style.bar.iconSlot)
            function openMenu(item, app) {
                if (!visible) return;
                menuItem = item; menuApp = app; menuOpen = true; tooltipReady = false;
            }
            Timer { id: tooltipDelay; interval: 450; onTriggered: dock.tooltipReady = dock.visible && dock.hoverItem !== null }
            Connections {
                target: root
                function onMenuRequested(key) {
                    for (let i = 0; i < appRepeater.count; ++i) {
                        const item = appRepeater.itemAt(i);
                        if (item && item.app.key === key) { dock.openMenu(item, item.app); return; }
                    }
                }
            }

            Flickable {
                id: viewport
                anchors.centerIn: parent
                width: Math.min(parent.width - 16, icons.width)
                height: parent.height
                contentWidth: icons.width
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                interactive: false // Pointer gestures reorder icons; wheel scrolling remains available.
                Row {
                    id: icons
                    height: dock.height
                    Repeater {
                        id: appRepeater
                        model: root.apps
                        delegate: Item {
                            id: slot
                            required property var modelData
                            required property int index
                            readonly property var app: modelData
                            readonly property bool active: app.windows.some(w => w.activated)
                            readonly property bool urgent: app.windows.some(w => w.urgent)
                            width: dock.slotWidth + (!app.pinned && index > 0 && root.apps[index - 1].pinned ? 9 : 0)
                            height: dock.height
                            Rectangle {
                                visible: !slot.app.pinned && slot.index > 0 && root.apps[slot.index - 1].pinned
                                width: 1; height: parent.height * 0.55
                                anchors.verticalCenter: parent.verticalCenter
                                color: Commons.Color.muted
                            }
                            Rectangle {
                                x: parent.width - dock.slotWidth + 2
                                width: dock.slotWidth - 4; height: parent.height
                                color: Commons.Color.bar.text
                                opacity: mouse.containsMouse ? 0.13 : slot.active ? 0.08 : 0
                                radius: 2
                            }
                            Image {
                                id: icon
                                x: parent.width - dock.slotWidth / 2 - width / 2
                                y: Math.max(1, (parent.height - height) / 2 - 1)
                                width: Math.min(root.barHeight - 6, Commons.Style.bar.iconCanvas)
                                height: width
                                source: root.iconSource(slot.app.icon)
                                Image {
                                    anchors.fill: parent
                                    visible: icon.status === Image.Error
                                    source: root.fallbackIcon
                                }
                                sourceSize.width: width * dock.screen.devicePixelRatio
                                sourceSize.height: height * dock.screen.devicePixelRatio
                                smooth: true
                                opacity: dock.dragKey === slot.app.key ? 0.25 : root.pendingLaunches[slot.app.key] && !slot.app.windows.length ? 0.45 : 1
                            }
                            Rectangle {
                                visible: slot.app.windows.length > 0
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                x: parent.width - dock.slotWidth / 2 - width / 2
                                width: slot.active ? 10 : 3; height: 2; radius: 1
                                color: slot.urgent ? Commons.Color.urgent : slot.active ? Commons.Color.accent : Commons.Color.bar.text
                            }
                            Rectangle {
                                visible: dock.dragKey !== "" && dock.dropKey === slot.app.key && dock.dragKey !== slot.app.key
                                x: dock.dropAfter ? parent.width - 1 : 0
                                width: 2; height: parent.height - 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: Commons.Color.accent
                            }
                            MouseArea {
                                id: mouse
                                property point pressPoint: Qt.point(0, 0)
                                property bool dragged: false
                                preventStealing: true
                                onPressed: event => {
                                    dragged = false;
                                    pressPoint = mapToItem(dock.contentItem, event.x, event.y);
                                }
                                onPositionChanged: event => {
                                    if (!(pressedButtons & Qt.LeftButton)) return;
                                    const point = mapToItem(dock.contentItem, event.x, event.y);
                                    if (!dragged && Math.abs(point.x - pressPoint.x) >= 6) {
                                        dragged = true;
                                        dock.menuOpen = false;
                                        dock.tooltipReady = false;
                                        tooltipDelay.stop();
                                        dock.dragKey = slot.app.key;
                                        dock.dragIcon = slot.app.icon || "application-x-executable";
                                    }
                                    if (dragged) dock.updateDrag(slot.app, point);
                                }
                                onReleased: event => {
                                    if (!dragged) return;
                                    const from = dock.dragKey, to = dock.dropKey, after = dock.dropAfter;
                                    dock.cancelDrag();
                                    // Persist only after release; rebuilding delegates mid-drag loses pointer capture.
                                    Qt.callLater(() => root.reorder(from, to, after));
                                }
                                onCanceled: { dragged = false; dock.cancelDrag(); }
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onEntered: { dock.hoverItem = slot; dock.tooltipReady = false; tooltipDelay.restart(); }
                                onExited: { if (dock.hoverItem === slot) dock.hoverItem = null; dock.tooltipReady = false; tooltipDelay.stop(); }
                                onClicked: event => {
                                    if (dragged) { dragged = false; return; }
                                    if (event.button === Qt.RightButton) dock.openMenu(slot, slot.app);
                                    else if (event.button === Qt.MiddleButton || (event.modifiers & Qt.ShiftModifier)) root.launch(slot.app);
                                    else if (slot.app.windows.length === 1) { dock.menuOpen = false; root.focusWindow(slot.app.windows[0]); }
                                    else if (slot.app.windows.length > 1) dock.openMenu(slot, slot.app);
                                    else { dock.menuOpen = false; root.launch(slot.app); }
                                }
                                onWheel: event => {
                                    viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - viewport.width, viewport.contentX - (event.angleDelta.y || event.angleDelta.x) / 2));
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }

            Image {
                id: draggedIcon
                visible: dock.dragKey !== ""
                z: 10
                x: dock.dragX - width / 2
                y: (dock.height - height) / 2 - 1
                width: Math.min(root.barHeight - 6, Commons.Style.bar.iconCanvas)
                height: width
                source: dock.dragIcon ? root.iconSource(dock.dragIcon) : ""
                Image {
                    anchors.fill: parent
                    visible: draggedIcon.status === Image.Error
                    source: root.fallbackIcon
                }
                sourceSize.width: width * dock.screen.devicePixelRatio
                sourceSize.height: height * dock.screen.devicePixelRatio
            }

            PopupWindow {
                id: tooltip
                visible: dock.visible && dock.dragKey === "" && dock.tooltipReady && dock.hoverItem !== null && !dock.menuOpen
                color: "transparent"
                implicitWidth: label.implicitWidth + 20
                implicitHeight: label.implicitHeight + 12
                anchor {
                    window: dock
                    edges: Edges.Top | Edges.Left
                    gravity: Edges.Bottom | Edges.Right
                    adjustment: PopupAdjustment.Slide
                    rect.width: 1; rect.height: 1
                    onAnchoring: {
                        if (!dock.hoverItem) return;
                        const p = dock.contentItem.mapFromItem(dock.hoverItem, dock.hoverItem.width / 2, 0);
                        tooltip.anchor.rect.x = Math.round(p.x - tooltip.width / 2);
                        tooltip.anchor.rect.y = -tooltip.height - 6;
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    color: Commons.Color.tooltip.background
                    radius: Commons.Style.cornerRadius
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: dock.hoverItem ? dock.hoverItem.app.name + (dock.hoverItem.app.windows.length ? " / " + dock.hoverItem.app.windows.length : "") : ""
                        textFormat: Text.PlainText
                        color: Commons.Color.tooltip.text
                        font.family: root.barFont
                        font.pixelSize: Commons.Style.font.body
                    }
                }
            }

            // A layer-shell surface receives input reliably with HyprlandFocusGrab.
            // An xdg popup is not a layer surface and can be excluded by that grab.
            PanelWindow {
                id: menu
                screen: dock.screen
                visible: dock.visible && dock.menuOpen && dock.menuItem !== null
                color: "transparent"
                implicitWidth: Math.min(Math.max(120, Number(root.settings.menuWidth) || 150), dock.screen.width - 24)
                implicitHeight: menuColumn.implicitHeight + 12
                anchors { left: true; bottom: true }
                margins.bottom: root.barHeight + 6
                margins.left: {
                    if (!dock.menuItem) return 12;
                    const p = dock.contentItem.mapFromItem(dock.menuItem, dock.menuItem.width / 2, 0);
                    return Math.round(Math.max(12, Math.min(dock.width - width - 12, p.x - width / 2)));
                }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "okumarchy-dock-menu"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                HyprlandFocusGrab {
                    active: menu.visible
                    windows: [menu, dock]
                    onCleared: dock.menuOpen = false
                }
                Rectangle {
                    anchors.fill: parent
                    color: Commons.Color.popups.background
                    radius: Commons.Style.cornerRadius
                    border.width: 1
                    border.color: Commons.Color.popups.border
                    Column {
                        id: menuColumn
                        x: 6; y: 6
                        width: parent.width - 12
                        Repeater {
                            model: {
                                if (!dock.menuApp) return [];
                                const app = root.apps.find(a => a.key === dock.menuApp.key) || dock.menuApp;
                                let rows = [{label: app.name, action: "heading"}];
                                for (const w of app.windows) rows.push({label: (w.workspace ? "[" + w.workspace.name + "] " : "") + w.title, action: "focus", window: w});
                                if (app.shellPlugin || app.command || app.desktop) rows.push({label: app.windows.length ? "New window / Launch" : "Launch", action: "launch"});
                                if (app.pinned || app.desktop) rows.push({label: app.pinned ? "Unpin from Dock" : "Pin to Dock", action: "pin"});
                                if (app.windows.length === 1) rows.push({label: "Close window", action: "close", window: app.windows[0]});
                                return rows;
                            }
                            delegate: Rectangle {
                                required property var modelData
                                width: menuColumn.width; height: Commons.Style.font.body + 18
                                color: menuMouse.containsMouse && modelData.action !== "heading" ? Commons.Color.menu.selectedBackground : "transparent"
                                Text {
                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                    text: modelData.label
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: root.barFont
                                    font.pixelSize: Commons.Style.font.body
                                    font.bold: modelData.action === "heading"
                                    color: Commons.Color.popups.text
                                }
                                MouseArea {
                                    id: menuMouse
                                    anchors.fill: parent; hoverEnabled: true
                                    onClicked: {
                                        const row = parent.modelData;
                                        if (row.action === "heading") return;
                                        // Release the input grab before focusing or launching an app.
                                        dock.menuOpen = false;
                                        if (row.action === "focus") root.focusWindow(row.window);
                                        else if (row.action === "launch") root.launch(dock.menuApp);
                                        else if (row.action === "pin") root.pin(dock.menuApp);
                                        else if (row.action === "close" && row.window) {
                                            const address = String(row.window.address).replace(/^0x/, "");
                                            if (/^[0-9a-f]+$/i.test(address)) Quickshell.execDetached(["hyprctl", "eval", 'hl.dispatch(hl.dsp.window.close({window="address:0x' + address + '"}))']);
                                        }
                                        dock.menuOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

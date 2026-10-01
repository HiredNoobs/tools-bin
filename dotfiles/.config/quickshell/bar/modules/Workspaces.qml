import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components

// Workspaces 1-5 are always shown; others appear when they exist on this monitor.
// Occupied workspaces are pills holding one icon per app; empty ones are dots.
Row {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int persistent: 5

    readonly property var entries: {
        const existing = Hyprland.workspaces.values.filter(ws => !ws.name.startsWith("special:"));
        const shown = [];

        for (let id = 1; id <= persistent; id++)
            shown.push({ name: String(id), workspace: existing.find(ws => ws.id === id) ?? null });

        existing
            .filter(ws => (ws.id < 1 || ws.id > persistent) && ws.monitor === monitor)
            .sort((a, b) => a.id - b.id)
            .forEach(ws => shown.push({ name: ws.name, workspace: ws }));

        return shown;
    }

    // Icon path for an app, or "" when there's no real icon (no placeholder images)
    function iconFor(name: string): string {
        if (name.startsWith("/"))
            return `file://${name}`;
        return Quickshell.iconPath(name, true);
    }

    // One entry per app in the workspace that has an icon: the icon and the first of its windows.
    // Windows without one (e.g. the GPG password prompt) are left out.
    function appsIn(workspace: HyprlandWorkspace): var {
        // Re-run once desktop entries have loaded, so icons resolve
        DesktopEntries.applications.values.length;

        const apps = [];
        for (const window of workspace?.toplevels.values ?? []) {
            const appId = window.wayland?.appId || window.lastIpcObject.class || "";
            if (apps.some(app => app.appId === appId))
                continue;
            const entry = DesktopEntries.heuristicLookup(appId);
            const icon = iconFor(entry?.icon || appId);
            if (icon === "")
                continue;
            apps.push({
                appId: appId,
                name: entry?.name || appId,
                icon: icon,
                window: window
            });
        }
        return apps;
    }

    function focusWorkspace(name: string): void {
        const escaped = name.replace(/["\\]/g, "\\$&");
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "${escaped}" })`);
    }

    function focusWindow(window: HyprlandToplevel): void {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${window.address}" })`);
    }

    leftPadding: 5
    rightPadding: 5
    spacing: 4

    Repeater {
        model: root.entries

        Item {
            id: entry

            required property var modelData
            readonly property HyprlandWorkspace workspace: modelData.workspace
            readonly property bool active: root.monitor?.activeWorkspace?.name === modelData.name
            readonly property var apps: root.appsIn(workspace)
            readonly property bool occupied: apps.length > 0
            // Has windows, but none with an icon: shown as a dot that isn't the "empty" grey
            readonly property bool hasWindows: (workspace?.toplevels.values.length ?? 0) > 0

            width: occupied ? pill.width : dot.width
            height: root.height

            // No icons to show: accent when active, faded accent when it has windows,
            // muted grey when empty; a little brighter on hover
            Text {
                id: dot

                visible: !entry.occupied
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 5
                rightPadding: 5
                text: "\u{F111}"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: {
                    if (entry.active)
                        return Theme.accent;
                    if (entry.hasWindows)
                        return Qt.alpha(Theme.accent, dotMouse.containsMouse ? 0.6 : 0.4);
                    return Qt.alpha(Theme.text, dotMouse.containsMouse ? 0.45 : 0.25);
                }

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                MouseArea {
                    id: dotMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.focusWorkspace(entry.modelData.name)
                }
            }

            // Occupied workspace: pill of app icons, accent-tinted and outlined when active
            Rectangle {
                id: pill

                visible: entry.occupied
                anchors.verticalCenter: parent.verticalCenter
                width: icons.implicitWidth + 16
                height: 24
                radius: height / 2
                color: entry.active ? Qt.alpha(Theme.accent, 0.25) : pillMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                border.width: entry.active ? 1.5 : 0
                border.color: Theme.accent

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                // Clicking the pill outside an icon switches to the workspace
                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.focusWorkspace(entry.modelData.name)
                }

                Row {
                    id: icons
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: entry.apps

                        // Clicking an icon focuses that app's window
                        MouseArea {
                            id: app

                            required property var modelData

                            width: 16
                            height: 16
                            hoverEnabled: true
                            onClicked: root.focusWindow(modelData.window)

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: app.containsMouse ? 18 : 16
                                source: app.modelData.icon
                                opacity: entry.active || app.containsMouse ? 1 : 0.7

                                Behavior on implicitSize {
                                    NumberAnimation { duration: 120 }
                                }
                            }

                            LazyLoader {
                                active: app.containsMouse

                                Tooltip {
                                    target: app
                                    text: app.modelData.name
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

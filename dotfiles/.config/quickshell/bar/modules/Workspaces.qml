import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.services

// This monitor's workspaces: each monitor has its own 1-10 (see WorkspaceRanges). 1-5 are
// always shown, 6-10 when they exist. Workspaces from another monitor's range sitting here
// (e.g. after unplugging that screen) and named ones like games follow after a divider.
// Occupied workspaces are pills holding one icon per app; empty ones are dots.
Row {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int persistent: 5
    readonly property int offset: WorkspaceRanges.offsetFor(monitor?.name ?? "")

    readonly property var entries: {
        const existing = Hyprland.workspaces.values.filter(ws => !ws.name.startsWith("special:"));
        const own = id => id > offset && id <= offset + 10;
        const shown = [];

        for (let n = 1; n <= persistent; n++) {
            const id = offset + n;
            shown.push({ name: String(id), workspace: existing.find(ws => ws.id === id) ?? null });
        }

        const here = existing.filter(ws => ws.monitor === monitor).sort((a, b) => a.id - b.id);
        here.filter(ws => own(ws.id) && ws.id > offset + persistent)
            .forEach(ws => shown.push({ name: ws.name, workspace: ws }));

        // Not part of this monitor's range, marked by a divider before the first one
        here.filter(ws => !own(ws.id))
            .forEach((ws, index) => shown.push({ name: ws.name, workspace: ws, dividerBefore: index === 0 }));

        return shown;
    }

    // One entry per app in the workspace that has an icon: the icon and the first of its windows.
    // Windows without one (e.g. the GPG password prompt) are left out.
    function appsIn(workspace: HyprlandWorkspace): var {
        const apps = [];
        for (const window of workspace?.toplevels.values ?? []) {
            const appId = Windows.appIdOf(window);
            if (apps.some(app => app.appId === appId))
                continue;
            const icon = Icons.forApp(appId);
            if (icon === "")
                continue;
            apps.push({
                appId: appId,
                icon: icon,
                window: window
            });
        }
        return apps;
    }

    // By id (Exec.workspace): a named one by its name, so it can't be taken for a relative move
    function focusWorkspace(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${Exec.workspace(id)} })`);
    }

    leftPadding: 5
    rightPadding: 5
    spacing: 4

    // Kept by name, so a workspace coming or going doesn't make every pill (and icon) again
    Repeater {
        model: ScriptModel {
            values: root.entries.map(shown => shown.name)
        }

        Item {
            id: entry

            required property string modelData
            readonly property var shown: root.entries.find(e => e.name === modelData) ?? { name: modelData, workspace: null }
            readonly property HyprlandWorkspace workspace: shown.workspace
            readonly property bool active: root.monitor?.activeWorkspace?.name === modelData
            readonly property var apps: root.appsIn(workspace)
            readonly property bool occupied: apps.length > 0
            // Has windows, but none with an icon: shown as a dot that isn't the "empty" grey
            readonly property bool hasWindows: (workspace?.toplevels.values.length ?? 0) > 0

            // Room for the divider before workspaces from another monitor's range
            readonly property int inset: shown.dividerBefore ? 12 : 0

            width: inset + (occupied ? pill.width : dot.width)
            height: root.height

            Rectangle {
                visible: entry.shown.dividerBefore ?? false
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                width: 1
                height: 14
                color: Theme.subtext
            }

            // No icons to show: accent when active, faded accent when it has windows,
            // muted grey when empty; a little brighter on hover
            Text {
                id: dot
                x: entry.inset

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
                    onClicked: root.focusWorkspace(entry.workspace?.id ?? Number(entry.modelData))
                }
            }

            // Occupied workspace: pill of app icons, accent-tinted and outlined when active
            Rectangle {
                id: pill
                x: entry.inset

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
                    onClicked: root.focusWorkspace(entry.workspace?.id ?? Number(entry.modelData))
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
                            onClicked: Windows.focus(modelData.window)

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: app.containsMouse ? 18 : 16
                                source: app.modelData.icon
                                opacity: entry.active || app.containsMouse ? 1 : 0.7

                                Behavior on implicitSize {
                                    NumberAnimation { duration: 120 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

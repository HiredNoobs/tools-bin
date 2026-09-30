import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// Workspaces 1-5 are always shown; others appear when they exist on this monitor
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

    topPadding: 7
    bottomPadding: 7
    leftPadding: 5
    rightPadding: 5

    Repeater {
        model: root.entries

        Text {
            id: button

            required property var modelData
            readonly property HyprlandWorkspace workspace: modelData.workspace
            readonly property bool active: root.monitor?.activeWorkspace?.name === modelData.name
            readonly property bool empty: !workspace || workspace.toplevels.values.length === 0

            height: root.height - root.topPadding - root.bottomPadding
            leftPadding: 5
            rightPadding: 5
            verticalAlignment: Text.AlignVCenter
            text: "\u{F111}"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize

            // Mirrors styles/hypr/workspaces.css: active solid, occupied faded, empty hollow
            readonly property bool hollow: !active && (empty || mouse.containsMouse)

            color: active ? Theme.accent : hollow ? "transparent" : Qt.alpha(Theme.accent, 0.4)
            style: hollow ? Text.Outline : Text.Normal
            styleColor: mouse.containsMouse ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.2)

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    const name = button.modelData.name.replace(/["\\]/g, "\\$&");
                    Hyprland.dispatch(`hl.dsp.focus({ workspace = "${name}" })`);
                }
            }
        }
    }
}

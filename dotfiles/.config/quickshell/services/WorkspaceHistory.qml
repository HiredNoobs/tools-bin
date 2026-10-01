pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace ids, most recently used first, for the Alt+Tab switcher. A workspace counts once it
// has stayed focused for a moment, so passing through one (e.g. the overview's window drops,
// which focus other workspaces briefly) doesn't reorder the list.
Singleton {
    id: root

    property var order: []

    function record(id: int): void {
        order = [id, ...order.filter(other => other !== id)];
    }

    Component.onCompleted: {
        if (Hyprland.focusedWorkspace)
            record(Hyprland.focusedWorkspace.id);
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged(): void {
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: {
            if (Hyprland.focusedWorkspace)
                root.record(Hyprland.focusedWorkspace.id);
        }
    }
}

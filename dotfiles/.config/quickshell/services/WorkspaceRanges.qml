pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Which workspace ids belong to which monitor, read from Hyprland's workspace rules. The
// Hyprland config (hypr/hyprland/workspaces.lua) gives each monitor its own 1-10 (main 1-10,
// second 11-20, ...) and is the single source of truth.
Singleton {
    id: root

    // Monitor name -> first id minus one (0 for main, 10 for second, ...)
    property var offsets: ({})

    function offsetFor(monitorName: string): int {
        return offsets[monitorName] ?? 0;
    }

    function refresh(): void {
        query.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["hyprctl", "workspacerules", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = {};
                    for (const rule of JSON.parse(text)) {
                        const id = Number(rule.workspaceString);
                        if (rule.enabled === false || !rule.monitor || !Number.isInteger(id) || id < 1)
                            continue;
                        const offset = Math.floor((id - 1) / 10) * 10;
                        if (!(rule.monitor in result) || offset < result[rule.monitor])
                            result[rule.monitor] = offset;
                    }
                    root.offsets = result;
                } catch (e) {
                    root.offsets = {};
                }
            }
        }
    }

    // Ranges change when screens come and go, or the config reloads
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: root.refresh()
    }
}

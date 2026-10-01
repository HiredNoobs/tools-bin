pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// Opening a tray app from the bar: activate it, then focus its window. Window rules stop
// apps like Discord from grabbing focus themselves; choosing one in the panel is explicit.
Singleton {
    id: root

    property SystemTrayItem pending: null
    property int attemptsLeft: 0

    function open(item: SystemTrayItem): void {
        item.activate();
        pending = item;
        // The app may need a moment to (re)open its window
        attemptsLeft = 10;
        Hyprland.refreshToplevels();
        retry.restart();
    }

    // Tray ids are usually the app name or window class. Electron apps use
    // "<name>_status_icon_N" (Discord: "discord_status_icon_1").
    function namesFor(item: SystemTrayItem): var {
        return [item.id, item.title, item.tooltipTitle]
            .filter(name => name)
            .map(name => name.toLowerCase().replace(/_status_icon_\d+$/, ""));
    }

    function windowFor(item: SystemTrayItem): var {
        const names = namesFor(item);
        return Hyprland.toplevels.values.find(window => {
            const ipc = window.lastIpcObject;
            const classes = [ipc.class, ipc.initialClass].filter(c => c).map(c => c.toLowerCase());
            return classes.some(c => names.includes(c));
        });
    }

    Timer {
        id: retry
        interval: 200
        onTriggered: {
            const window = root.pending ? root.windowFor(root.pending) : null;
            if (window) {
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${window.address}" })`);
                root.pending = null;
            } else if (--root.attemptsLeft > 0) {
                Hyprland.refreshToplevels();
                restart();
            } else {
                root.pending = null;
            }
        }
    }
}

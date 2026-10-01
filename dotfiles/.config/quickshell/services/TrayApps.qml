pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Opening a tray app from the bar: activate it, then focus its window (see Windows).
Singleton {
    function open(item: SystemTrayItem): void {
        item.activate();
        Windows.focusApp(namesFor(item), "");
    }

    // Tray ids are usually the app name or window class. Electron apps use
    // "<name>_status_icon_N" (Discord: "discord_status_icon_1").
    function namesFor(item: SystemTrayItem): var {
        return [item.id, item.title, item.tooltipTitle]
            .filter(name => name)
            .map(name => name.toLowerCase().replace(/_status_icon_\d+$/, ""));
    }
}

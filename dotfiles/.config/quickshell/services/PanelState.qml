pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// Which expandable sections of the panels are open, so they stay open across closing and
// reopening a panel until collapsed. Kept for this session only, and dropped once the thing
// they belong to is gone (e.g. an app's audio streams or notifications, a monitor, a note).
// Sections: "audio" (app names with several streams), "devices" ("output", "input"),
// "notifications" (app names), "monitors" and "modes" (monitor names), "notes" (note ids),
// "updates" ("list"), "trayApps" (tray app ids), "trayMenus" ("<app id>/<entry>/…") and
// "settings" (the settings window's expandable rows, e.g. "attach").
// Drop-down choices (devices, modes) still close once something is chosen.
Singleton {
    id: root

    // { section: { key: true } }
    property var open: ({})

    function isOpen(section: string, key: string): bool {
        return open[section]?.[key] ?? false;
    }

    function toggle(section: string, key: string): void {
        const keys = Object.assign({}, open[section]);
        if (keys[key])
            delete keys[key];
        else
            keys[key] = true;
        open = Object.assign({}, open, { [section]: keys });
    }

    // Forget open sections whose key isn't in `present` (or, with `byPrefix`, doesn't start
    // with "<one of present>/")
    function prune(section: string, present: var, byPrefix: var): void {
        const keys = open[section];
        if (!keys)
            return;
        const kept = {};
        for (const key of Object.keys(keys)) {
            if (byPrefix ? present.some(prefix => key.startsWith(prefix + "/")) : present.includes(key))
                kept[key] = true;
        }
        if (Object.keys(kept).length !== Object.keys(keys).length)
            open = Object.assign({}, open, { [section]: kept });
    }

    // Pruned as they change, even while the panels are closed (monitors, modes and notes are pruned
    // by their panels, the only place they change from or matter)

    // Apps with more than one stream, the only ones that have a list to open
    readonly property var audioGroups: {
        const counts = {};
        for (const node of Pipewire.nodes.values) {
            if (node.type === PwNodeType.AudioOutStream) {
                const app = node.properties["application.name"] ?? node.name;
                counts[app] = (counts[app] ?? 0) + 1;
            }
        }
        return Object.keys(counts).filter(app => counts[app] > 1);
    }
    onAudioGroupsChanged: prune("audio", audioGroups)

    readonly property var notificationApps: Notifications.groups.map(group => group.app)
    onNotificationAppsChanged: prune("notifications", notificationApps)

    readonly property var trayApps: SystemTray.items.values.map(item => item.id)
    onTrayAppsChanged: {
        prune("trayApps", trayApps);
        prune("trayMenus", trayApps, true);
    }

    readonly property bool hasUpdates: Updates.packages.length > 0
    onHasUpdatesChanged: {
        if (!hasUpdates)
            prune("updates", []);
    }
}

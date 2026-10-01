pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Focuses an app's window when you explicitly ask for it (tray apps, the media panel's Open
// button), switching workspace if needed. Window rules stop apps like Discord and Firefox
// from taking focus on their own; choosing one from the bar is explicit.
Singleton {
    id: root

    property var pendingNames: []
    property string pendingTitle: ""
    property int attemptsLeft: 0

    // names: app names or ids to match against window classes (case-insensitive).
    // preferTitle: among several matching windows, prefer one whose title contains this
    // (e.g. Firefox's window with the playing tab).
    function focusApp(names: var, preferTitle: string): void {
        pendingNames = names.filter(name => name).map(name => name.toLowerCase());
        pendingTitle = preferTitle ?? "";
        // The app may need a moment to (re)open its window
        attemptsLeft = 10;
        Hyprland.refreshToplevels();
        retry.restart();
    }

    function windowFor(names: var, preferTitle: string): var {
        const matches = Hyprland.toplevels.values.filter(window => {
            const ipc = window.lastIpcObject;
            const classes = [ipc.class, ipc.initialClass].filter(c => c).map(c => c.toLowerCase());
            return classes.some(c => names.includes(c));
        });
        if (preferTitle) {
            const titled = matches.find(window => (window.title ?? "").includes(preferTitle));
            if (titled)
                return titled;
        }
        return matches[0] ?? null;
    }

    Timer {
        id: retry
        interval: 200
        onTriggered: {
            const window = root.windowFor(root.pendingNames, root.pendingTitle);
            if (window) {
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${window.address}" })`);
                root.attemptsLeft = 0;
            } else if (--root.attemptsLeft > 0) {
                Hyprland.refreshToplevels();
                restart();
            }
        }
    }
}

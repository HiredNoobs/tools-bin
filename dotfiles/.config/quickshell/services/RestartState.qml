pragma Singleton

import QtQuick
import Quickshell
import qs

// What's on screen, kept across a restart the shell does itself (changing its icons, see
// Appearance, or Settings › Shell's restart button): whether the settings window is open, its
// page and scroll position, and the panels' and settings' open sections and pickers
// (PanelState). Saved just before, read back once at the next start and then deleted, so an
// ordinary start, or closing the window, begins fresh.
Singleton {
    id: root

    // While the settings window is open: its page and scroll position
    property bool windowOpen: false
    property string page: ""
    property real scrollY: 0
    // Read back at start, until the window has used it
    property var restored: null

    function windowClosed(): void {
        windowOpen = false;
        scrollY = 0;
    }

    // With the time, as FileView skips writing the text it last read (deleted since, so the
    // same state twice in a row would be lost)
    function save(): void {
        file.save({
            savedAt: Date.now(),
            windowOpen: windowOpen,
            page: page,
            scrollY: scrollY,
            panels: PanelState.open
        });
    }

    // Restarts the shell through Hyprland (so it gets Hyprland's current environment, e.g. new
    // icons), a second from now so changes being saved finish; the settings window comes back
    // as it was once the new shell answers
    function restartShell(): void {
        save();
        Exec.viaHyprland(`sh -c 'sleep 1; pkill -x qs; while pgrep -x qs >/dev/null; do sleep 0.1; done; qs & sleep 1; for try in $(seq 40); do [ -z "$(qs ipc call settings restore 2>&1)" ] && break; sleep 0.25; done'`, "");
    }

    // In case the window never comes back to use it
    Timer {
        id: forgetTimer
        interval: 30000
        onTriggered: root.restored = null
    }

    // Read once, then deleted (an unreadable one is kept aside like the others)
    JsonFile {
        id: file
        path: Quickshell.statePath("restart-state.json")
        blocking: true
        fallback: null
        onRead: state => {
            Exec.run(`rm -f ${Exec.quote(file.path)}`);
            if (!state)
                return;
            PanelState.open = state.panels ?? {};
            root.restored = state;
            forgetTimer.start();
        }
    }
}

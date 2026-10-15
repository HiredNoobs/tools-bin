pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// What's on screen, kept across a restart the shell does itself (changing its icons, see
// Appearance, or Settings › Shell's restart button): whether the settings window is open, its page, scroll position and open pickers,
// and the panels' open sections (PanelState). Saved just before, read back once at the next
// start and then deleted, so an ordinary start, or closing the window, begins fresh.
Singleton {
    id: root

    // While the settings window is open: its page, scroll position, and open pickers by name
    property bool windowOpen: false
    property string page: ""
    property real scrollY: 0
    property var pickers: ({})
    // Read back at start, until the window has used it
    property var restored: null

    function setPicker(key: string, open: bool): void {
        const updated = Object.assign({}, pickers);
        if (open)
            updated[key] = true;
        else
            delete updated[key];
        pickers = updated;
    }

    // A picker's state from before the restart (closed otherwise)
    function pickerOpen(key: string): bool {
        return restored?.pickers?.[key] ?? false;
    }

    function windowClosed(): void {
        windowOpen = false;
        scrollY = 0;
        pickers = {};
    }

    // With the time, as FileView skips writing the text it last read (deleted since, so the
    // same state twice in a row would be lost)
    function save(): void {
        file.setText(JSON.stringify({
            savedAt: Date.now(),
            windowOpen: windowOpen,
            page: page,
            scrollY: scrollY,
            pickers: pickers,
            panels: PanelState.open
        }));
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

    FileView {
        id: file
        path: Quickshell.statePath("restart-state.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const state = JSON.parse(text());
                PanelState.open = state.panels ?? {};
                root.restored = state;
                forgetTimer.start();
            } catch (e) {}
            Exec.run(`rm -f ${Exec.quote(path)}`);
        }
    }
}

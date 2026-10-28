pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Screens by Hyprland's monitor name, for pop-ups that open on the focused monitor and stay
// there (taken when they open, as focus can move while they're up)
Singleton {
    // The focused monitor's name ("" before Hyprland has said)
    function focusedName(): string {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    // The screen with that name, or the first one
    function byName(name: string): ShellScreen {
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }
}

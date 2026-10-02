pragma Singleton

import Quickshell

// "Keep awake" in the system panel: while on, a Wayland idle inhibitor (on the bar, see
// shell.qml) stops hypridle's timers, so the screen doesn't lock, turn off or suspend. Only for
// this session; a restart of the shell turns it off.
Singleton {
    property bool enabled: false
}

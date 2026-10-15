pragma Singleton

import QtQuick
import Quickshell
import qs

// "Keep awake" in the system panel: while on, a Wayland idle inhibitor (on the bar, see
// shell.qml) stops hypridle's timers, so the screen doesn't lock, turn off or suspend. Saved in
// ShellSettings, so it stays on through restarts of the shell or the session.
Singleton {
    id: root

    property bool enabled: ShellSettings.keepAwake

    onEnabledChanged: ShellSettings.keepAwake = enabled

    // Setting enabled ends its binding, so follow the saved value by hand
    Connections {
        target: ShellSettings

        function onKeepAwakeChanged(): void {
            root.enabled = ShellSettings.keepAwake;
        }
    }
}

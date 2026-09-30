//@ pragma UseQApplication
// UseQApplication is needed for tray items' native menus

import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar

ShellRoot {
    id: root

    property bool barVisible: true

    // One bar per monitor
    Variants {
        model: Quickshell.screens

        Bar {
            visible: root.barVisible
        }
    }

    // `qs ipc call bar toggle`
    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }
}

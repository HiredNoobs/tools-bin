import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.bar

ShellRoot {
    id: root

    property bool barVisible: true

    // One bar per monitor
    Variants {
        id: bars
        model: Quickshell.screens

        Bar {
            visible: root.barVisible
        }
    }

    // `qs ipc call bar toggle` / `qs ipc call bar panel calendar`
    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barVisible = !root.barVisible;
        }

        // Toggle a panel on the focused monitor's bar
        function panel(name: string): void {
            const monitor = Hyprland.focusedMonitor?.name;
            bars.instances.find(bar => bar.screen.name === monitor)?.togglePanelByName(name);
        }
    }
}

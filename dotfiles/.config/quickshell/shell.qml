//@ pragma IconTheme Papirus-Dark
// Icons from Papirus-Dark (installed by the setup script), so apps' and devices' icon names
// resolve; without a theme only the basic hicolor set is found

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.bar
import qs.launcher
import qs.overview
import qs.services
import qs.switcher

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

    // Super+Tab
    Overview {
        id: overview
    }

    // `qs ipc call overview toggle`
    IpcHandler {
        target: "overview"

        function toggle(): void {
            overview.toggle();
        }
    }

    // Super+Space
    Launcher {
        id: launcher
    }

    // `qs ipc call launcher toggle`
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.toggle();
        }
    }

    // Alt+Tab
    AltTab {
        id: switcher
    }

    // Driven by the Alt+Tab binds: `qs ipc call switcher next <session>`, `prev`, `commit`
    IpcHandler {
        target: "switcher"

        function next(session: int): void {
            switcher.step(session, 1);
        }

        function prev(session: int): void {
            switcher.step(session, -1);
        }

        function commit(session: int): void {
            switcher.commit(session);
        }

        function cancel(): void {
            switcher.cancel();
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

    // `qs ipc call notifications dnd` / `qs ipc call notifications clear`
    IpcHandler {
        target: "notifications"

        function dnd(): void {
            Notifications.dnd = !Notifications.dnd;
        }

        function clear(): void {
            Notifications.clearAll();
        }
    }
}

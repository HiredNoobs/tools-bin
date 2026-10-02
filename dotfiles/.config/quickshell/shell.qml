//@ pragma IconTheme Papirus-Dark
// Icons from Papirus-Dark (installed by the setup script), so apps' and devices' icon names
// resolve; without a theme only the basic hicolor set is found

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.bar
import qs.launcher
import qs.overview
import qs.services
import qs.settings
import qs.switcher

ShellRoot {
    id: root

    property bool barVisible: true

    // Singletons are only created when first used; create these at start so update checks run
    // on schedule, stream titles are remembered before the panels first open, and the
    // Bluetooth pairing agent is there before anything pairs
    Component.onCompleted: {
        Updates.available;
        StreamTitles.titles;
        BluetoothAgent.ready;
    }

    // A window for each Bluetooth pairing request, there until answered (or closed, which
    // rejects) or cancelled by the device
    LazyLoader {
        active: BluetoothAgent.request !== null

        PairingWindow {
            onClosed: BluetoothAgent.answer(false, "")
        }
    }

    // One bar per monitor
    Variants {
        id: bars
        model: Quickshell.screens

        Bar {
            visible: root.barVisible
        }
    }

    // The system panel's Keep awake: inhibits idle (hypridle) while on, through the first bar
    IdleInhibitor {
        window: bars.instances[0] ?? null
        enabled: KeepAwake.enabled
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

    // `qs ipc call launcher toggle` (Super+Space), `screenshot` (Print), `wallpaper`
    IpcHandler {
        target: "launcher"

        // Under the focused monitor's bar, or the centred popup
        function show(name: string): void {
            if (Theme.launcherAttached) {
                const monitor = Hyprland.focusedMonitor?.name;
                bars.instances.find(bar => bar.screen.name === monitor)?.togglePanelByName(name);
            } else {
                launcher.toggle(name);
            }
        }

        function toggle(): void {
            show("launcher");
        }

        function screenshot(): void {
            show("screenshot");
        }

        function wallpaper(): void {
            show("wallpaper");
        }
    }

    // Super+I: the settings window, made when opened and gone once closed
    property string settingsPage: "shell"

    LazyLoader {
        id: settingsWindow

        SettingsWindow {
            page: root.settingsPage
            onPageRequested: name => root.settingsPage = name
            onClosed: settingsWindow.active = false
            onVisibleChanged: {
                if (!visible)
                    settingsWindow.active = false;
            }
        }
    }

    // `qs ipc call settings open [section]` (Super+I opens it where it was left), `close`
    IpcHandler {
        target: "settings"

        function open(section: string): void {
            if (section !== "")
                root.settingsPage = section;
            if (settingsWindow.active)
                Windows.focusApp(["org.quickshell"], "Settings");
            else
                settingsWindow.active = true;
        }

        function close(): void {
            settingsWindow.active = false;
        }
    }

    // `qs ipc call cheatsheet toggle` (Super+F1): always the centred popup, too wide for the bar
    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            launcher.toggle("cheatsheet");
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

    // `qs ipc call updates check`, after pacman -Syu from the system panel
    IpcHandler {
        target: "updates"

        function check(): void {
            Updates.check();
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

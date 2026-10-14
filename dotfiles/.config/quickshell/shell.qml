// The icon theme comes from QS_ICON_THEME (env.lua's default, then Settings › Appearance's
// choice in appearance.lua); without one only the basic hicolor set is found

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.bar
import qs.launcher
import qs.lock
import qs.osd
import qs.overview
import qs.polkit
import qs.services
import qs.settings
import qs.switcher
import qs.wallpaper

ShellRoot {
    id: root

    property bool barVisible: true

    // Singletons are only created when first used; create these at start so update checks run
    // on schedule, stream titles are remembered before the panels first open, the Bluetooth
    // pairing agent is there before anything pairs, nightlight's schedule runs, the lid and low
    // battery are handled, the login screen gets the current wallpaper, colours and avatar, and
    // the colour scheme follows the wallpaper if it's set to, drives plugged in are mounted, and
    // the clipboard history starts, and the shell's icons follow Appearance's
    Component.onCompleted: {
        Updates.available;
        StreamTitles.titles;
        BluetoothAgent.ready;
        Nightlight.enabled;
        Lid.hasLid;
        LowBattery.warned;
        LockShare.shared;
        ColourScheme.current;
        Drives.drives;
        Clipboard.entries;
        Appearance.loaded;
    }

    // A window for each Bluetooth pairing request, there until answered (or closed, which
    // rejects) or cancelled by the device
    LazyLoader {
        active: BluetoothAgent.request !== null

        PairingWindow {
            onClosed: BluetoothAgent.answer(false, "")
        }
    }

    // The wallpaper, under everything on each monitor
    Variants {
        model: Quickshell.screens

        Background {}
    }

    // `qs ipc call wallpaper set <file>`, as picking it in the wallpaper menu
    IpcHandler {
        target: "wallpaper"

        function set(file: string): void {
            Wallpaper.set(file);
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

    // Password prompts for admin actions (the authentication agent)
    PolkitPrompt {}

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

    // The lockscreen (see LockScreen for what happens if the shell dies while locked)
    LockScreen {
        id: lockScreen
    }

    // `qs ipc call lock lock`, or `preview` to see it in a window without locking
    IpcHandler {
        target: "lock"

        function lock(): void {
            lockScreen.lock();
        }

        function preview(): void {
            lockScreen.preview();
        }
    }

    // Super+Space
    Launcher {
        id: launcher
    }

    // `qs ipc call launcher toggle` (Super+Space), `screenshot` (Print), `clipboard` (Super+V),
    // `wallpaper`
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

        function clipboard(): void {
            show("clipboard");
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

    // Volume, mic and brightness keys, when the pop-up isn't attached to the bar (OsdState)
    Osd {}

    // `qs ipc call osd volume up|down|mute`, `mic`, `brightness up|down` (keybinds.lua)
    IpcHandler {
        target: "osd"

        function volume(direction: string): void {
            OsdState.volume(direction);
        }

        function mic(): void {
            OsdState.mic();
        }

        function brightness(direction: string): void {
            OsdState.brightness(direction);
        }
    }

    // Hyprland's lid switch binds: `qs ipc call lid closed|opened`
    IpcHandler {
        target: "lid"

        function closed(): void {
            Lid.closed();
        }

        function opened(): void {
            Lid.opened();
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

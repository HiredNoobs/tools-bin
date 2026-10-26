pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// What closing the laptop lid does (Settings › Power and idle). While the shell runs it holds a
// systemd lid inhibitor, so logind leaves the lid alone, and Hyprland's lid switch binds
// (keybinds.lua) call `qs ipc call lid closed|opened`. If the shell isn't running the inhibitor
// is gone and logind's own handling (suspend) applies again.
Singleton {
    id: root

    property bool hasLid: false
    // The laptop screen's settings, while it's off because the lid closed
    property var laptopSpec: null

    function closed(): void {
        const laptop = Monitors.enabledMonitors.find(m => Monitors.isBuiltIn(m.name));
        const docked = Monitors.enabledMonitors.some(m => !Monitors.isBuiltIn(m.name));
        switch (docked ? ShellSettings.lidDocked : ShellSettings.lidAction) {
        case "suspend":
            Exec.run("systemctl suspend");
            break;
        case "lock":
            Exec.run("loginctl lock-session");
            break;
        case "screen-off":
            if (laptop && docked) {
                laptopSpec = Monitors.specOf(laptop);
                Monitors.setOffQuietly(laptop.name);
            }
            break;
        }
    }

    function opened(): void {
        if (laptopSpec) {
            Monitors.restoreQuietly(laptopSpec);
            laptopSpec = null;
        }
    }

    Process {
        command: ["test", "-d", "/proc/acpi/button/lid"]
        running: true
        onExited: code => root.hasLid = code === 0
    }

    // Held until this shell process is gone, however it ends (a child process outlives a killed
    // shell, which would leave the lid ignored)
    Process {
        running: root.hasLid
        command: ["systemd-inhibit", "--what=handle-lid-switch", "--who=Quickshell", "--why=The shell decides what closing the lid does", "--mode=block", "tail", `--pid=${Quickshell.processId}`, "-f", "/dev/null"]
    }
}

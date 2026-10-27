pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// What closing the laptop lid does (Settings › Power and idle). While the shell runs it holds a
// systemd lid inhibitor, so logind leaves the lid alone, and Hyprland's lid switch binds
// (keybinds.lua) call `qs ipc call lid closed|opened`. If the shell isn't running the inhibitor
// is gone and logind's own handling (suspend) applies again.
//
// With another screen, closing the lid can turn the laptop screen off. Its settings are kept in
// the state folder until the lid opens, so a restarted shell still turns it back on. Unplugging
// the other screen meanwhile turns it back on and does what closing the lid does undocked, and
// a config reload (which turns it on behind the lid) turns it off again.
Singleton {
    id: root

    property bool hasLid: false
    // The laptop screen's settings, while it's off because the lid closed
    property var laptopSpec: null
    // A config reload is being read back (see check)
    property bool reloaded: false
    // At start with a saved laptop screen: false until the lid's state has been read, then
    // whether it opened while no shell was running
    property bool lidKnown: true
    property bool openedMeanwhile: false

    readonly property bool docked: Monitors.enabledMonitors.some(m => !Monitors.isBuiltIn(m.name))

    function closed(): void {
        const laptop = Monitors.enabledMonitors.find(m => Monitors.isBuiltIn(m.name));
        if (docked && ShellSettings.lidDocked === "screen-off") {
            if (laptop) {
                setLaptopSpec(Monitors.specOf(laptop));
                Monitors.setOffQuietly(laptop.name);
            }
            return;
        }
        act(docked ? ShellSettings.lidDocked : ShellSettings.lidAction);
    }

    function opened(): void {
        if (laptopSpec) {
            Monitors.restoreQuietly(laptopSpec);
            setLaptopSpec(null);
        }
    }

    // "suspend" (locked first: hypridle locks before sleep, but only while it's running),
    // "lock" or "nothing"
    function act(action: string): void {
        if (action === "suspend")
            Exec.run(`${Exec.lockCommand}; systemctl suspend`);
        else if (action === "lock")
            Exec.run(Exec.lockCommand);
    }

    function setLaptopSpec(spec: var): void {
        laptopSpec = spec;
        savedSpec.setText(spec ? JSON.stringify(spec) + "\n" : "");
    }

    // Each time the monitors are read, while the laptop screen is off for the lid: the other
    // screen went, so the laptop's comes back on (there'd be no screen at all otherwise), then
    // as if the lid had closed undocked; or a config reload turned it on behind the lid, so
    // it's turned off again. Waits for the monitors (and at start, the lid) to be known.
    function check(): void {
        if (!lidKnown || !laptopSpec || Monitors.monitors.length === 0)
            return;
        if (openedMeanwhile) {
            openedMeanwhile = false;
            opened();
            return;
        }
        if (!docked) {
            opened();
            act(ShellSettings.lidAction);
            return;
        }
        const laptop = Monitors.byName(laptopSpec.output);
        if (reloaded && laptop && !laptop.disabled) {
            setLaptopSpec(Monitors.specOf(laptop));
            Monitors.setOffQuietly(laptop.name);
        }
        reloaded = false;
    }

    Connections {
        target: Monitors

        function onMonitorsChanged(): void {
            root.check();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "configreloaded" && root.laptopSpec)
                root.reloaded = true;
        }
    }

    FileView {
        id: savedSpec
        path: Quickshell.statePath("lid-screen.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.laptopSpec = text().trim() !== "" ? JSON.parse(text()) : null;
            } catch (e) {
                root.laptopSpec = null;
            }
            // It may have opened while no shell was running
            if (root.laptopSpec) {
                root.lidKnown = false;
                lidState.running = true;
            }
        }
    }

    Process {
        id: lidState
        command: ["sh", "-c", "cat /proc/acpi/button/lid/*/state"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.openedMeanwhile = /\bopen\b/.test(text);
                root.lidKnown = true;
                root.check();
            }
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

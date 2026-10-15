pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// External monitors' brightness over DDC/CI (ddcutil, with the i2c-dev module loaded), beside
// Brightness for the laptop's backlight. Monitors are found at start, when screens come or go,
// and when asked (the display panel opening). A change shows at once and is sent while the
// slider moves, the latest value whenever the last write is done. `available` is false without
// ddcutil or a monitor that answers.
//
// ddcutil checks a monitor before each command, which some monitors (an AOC here) answer only
// after seconds of retries; skipping it makes a read or write ~100 ms. Each connector's I2C bus
// comes from sysfs, as `ddcutil detect` takes as long as those checks.
Singleton {
    id: root

    // [{ name: Hyprland's connector (e.g. "HDMI-A-1"), bus, max }]; only changed by detecting,
    // so sliders built from it aren't rebuilt while they're dragged
    property var displays: []
    readonly property bool available: displays.length > 0
    // Connector -> brightness 0..1
    property var levels: ({})
    // Raw values waiting to be sent, by connector
    property var pending: ({})

    readonly property var ddcutil: ["ddcutil", "--skip-ddc-checks", "--maxtries", "3,3,3"]

    function display(name: string): var {
        return displays.find(d => d.name === name) ?? null;
    }

    function level(name: string): real {
        return levels[name] ?? 0;
    }

    function set(name: string, value: real): void {
        const target = display(name);
        if (!target)
            return;
        const clamped = Math.max(0, Math.min(1, value));
        const updatedLevels = Object.assign({}, levels);
        updatedLevels[name] = clamped;
        levels = updatedLevels;
        const updated = Object.assign({}, pending);
        updated[name] = Math.round(clamped * target.max);
        pending = updated;
        send();
    }

    // The pending values, unless a write is still going (it sends them when done)
    function send(): void {
        if (sender.running || Object.keys(pending).length === 0)
            return;
        const lines = [];
        for (const name in pending) {
            const target = display(name);
            if (target)
                lines.push(`${ddcutil.join(" ")} --bus ${target.bus} --noverify setvcp 10 ${pending[name]}`);
        }
        pending = {};
        if (lines.length > 0) {
            sender.command = ["sh", "-c", lines.join("\n")];
            sender.running = true;
        }
    }

    function detect(): void {
        if (!detector.running && !sender.running && Object.keys(pending).length === 0)
            detector.running = true;
    }

    Component.onCompleted: detect()

    // Screens plugged in or out: look again once the new one has settled
    readonly property int screenCount: Quickshell.screens.length
    onScreenCountChanged: detectTimer.restart()

    Timer {
        id: detectTimer
        interval: 3000
        onTriggered: root.detect()
    }

    Process {
        id: sender
        onExited: root.send()
    }

    // "connector<TAB>bus<TAB>VCP 10 C <current> <max>" per connected monitor that answers (not
    // the laptop's own screen); nothing without ddcutil. Each is asked up to three times, as
    // some miss the first message after a while idle.
    Process {
        id: detector
        command: ["sh", "-c", `
            command -v ddcutil >/dev/null || exit 0
            for connector in /sys/class/drm/card*-*; do
                [ -e "$connector/ddc" ] && [ "$(cat "$connector/status")" = connected ] || continue
                name=\${connector##*/card[0-9]-}
                case $name in eDP*) continue ;; esac
                bus=$(basename "$(readlink -f "$connector/ddc")")
                bus=\${bus#i2c-}
                for try in 1 2 3; do
                    vcp=$(${root.ddcutil.join(" ")} --bus "$bus" getvcp 10 --brief 2>/dev/null) && break
                    vcp=""
                    sleep 0.3
                done
                [ -n "$vcp" ] && printf '%s\\t%s\\t%s\\n' "$name" "$bus" "$vcp"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const levels = {};
                for (const line of text.split("\n")) {
                    const parts = line.split("\t");
                    const name = (parts[0] ?? "").trim();
                    const match = String(parts[2] ?? "").match(/^VCP 10 C (\d+) (\d+)/);
                    if (name && match && Number(match[2]) > 0) {
                        found.push({ name: name, bus: Number(parts[1]), max: Number(match[2]) });
                        levels[name] = Number(match[1]) / Number(match[2]);
                    }
                }
                // Same monitors: keep the list (and the sliders built from it)
                if (JSON.stringify(found) !== JSON.stringify(root.displays))
                    root.displays = found;
                root.levels = levels;
            }
        }
    }
}

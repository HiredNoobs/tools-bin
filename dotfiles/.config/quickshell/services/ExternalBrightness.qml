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
// comes from sysfs, as `ddcutil detect` takes as long as those checks (it's only the fallback).
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
    // When each connector was last set, and when the running detection started: a level set
    // meanwhile is newer than what detection read (not properties to bind to)
    property var setAt: ({})
    property real detectStarted: 0

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
        setAt[name] = Date.now();
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

    // Not while a write is going (they'd share the bus): tried again a moment later
    function detect(): void {
        if (detector.running)
            return;
        if (sender.running || Object.keys(pending).length > 0) {
            detectTimer.restart();
            return;
        }
        detectStarted = Date.now();
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
    // a laptop's own screen); nothing without ddcutil. Each is asked up to three times, as some
    // miss the first message after a while idle. The buses come from sysfs; drivers that don't
    // link them there (NVIDIA's own) fall back to `ddcutil detect`, which is slow but finds them.
    Process {
        id: detector
        command: ["sh", "-c", `
            command -v ddcutil >/dev/null || exit 0
            ask() {
                for try in 1 2 3; do
                    vcp=$(${root.ddcutil.join(" ")} --bus "$2" getvcp 10 --brief 2>/dev/null) && break
                    vcp=""
                    sleep 0.3
                done
                [ -n "$vcp" ] && printf '%s\\t%s\\t%s\\n' "$1" "$2" "$vcp"
            }
            builtin() { case $1 in eDP*|LVDS*|DSI*) return 0 ;; esac; return 1; }
            missing=0
            for connector in /sys/class/drm/card*-*; do
                [ "$(cat "$connector/status" 2>/dev/null)" = connected ] || continue
                name=\${connector##*/card[0-9]-}
                builtin "$name" && continue
                if [ -e "$connector/ddc" ]; then
                    bus=$(basename "$(readlink -f "$connector/ddc")")
                    ask "$name" "\${bus#i2c-}"
                else
                    missing=1
                fi
            done
            # No sysfs link for some monitor (or no DRM connectors at all): ask ddcutil
            if [ $missing = 1 ] || ! ls /sys/class/drm/card*-* >/dev/null 2>&1; then
                ddcutil detect --brief 2>/dev/null |
                    sed -n 's|.*I2C bus: */dev/i2c-\\([0-9]*\\).*|bus \\1|p; s|.*DRM[ _]connector: *card[0-9]*-\\(.*\\)|connector \\1|p' |
                    while read -r kind value; do
                        case $kind in
                            bus) bus=$value ;;
                            connector) builtin "$value" || [ -e /sys/class/drm/card*-"$value"/ddc ] || ask "$value" "$bus" ;;
                        esac
                    done
            fi
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
                        const newer = (root.setAt[name] ?? 0) > root.detectStarted && root.levels[name] !== undefined;
                        levels[name] = newer ? root.levels[name] : Number(match[1]) / Number(match[2]);
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

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// External monitors' brightness over DDC/CI (ddcutil, with the i2c-dev module loaded), beside
// Brightness for the laptop's backlight. Monitors are found at start, when screens come or go,
// and when asked (the display panel opening). A change shows at once but is only sent once the
// slider or keys have settled, as each DDC write takes 100 ms or more. `available` is false
// without ddcutil or a monitor that answers.
Singleton {
    id: root

    // [{ name: Hyprland's connector (e.g. "HDMI-A-1"), bus, level: 0..1, max }]
    property var displays: []
    readonly property bool available: displays.length > 0
    // Raw values waiting to be sent, by connector
    property var pending: ({})

    function display(name: string): var {
        return displays.find(d => d.name === name) ?? null;
    }

    function level(name: string): real {
        return display(name)?.level ?? 0;
    }

    function set(name: string, value: real): void {
        const target = display(name);
        if (!target)
            return;
        const clamped = Math.max(0, Math.min(1, value));
        displays = displays.map(d => d.name === name ? Object.assign({}, d, { level: clamped }) : d);
        const updated = Object.assign({}, pending);
        updated[name] = Math.round(clamped * target.max);
        pending = updated;
        applyTimer.restart();
    }

    function detect(): void {
        if (!detector.running && Object.keys(pending).length === 0)
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

    Timer {
        id: applyTimer
        interval: 400
        onTriggered: {
            for (const name in root.pending) {
                const target = root.display(name);
                if (target)
                    Quickshell.execDetached(["ddcutil", "--bus", String(target.bus), "--noverify", "setvcp", "10", String(root.pending[name])]);
            }
            root.pending = {};
        }
    }

    // "connector<TAB>bus<TAB>VCP 10 C <current> <max>" per monitor (the laptop's own screen and
    // monitors that don't answer are left out); nothing without ddcutil
    Process {
        id: detector
        command: ["sh", "-c", `
            command -v ddcutil >/dev/null || exit 0
            ddcutil detect --brief 2>/dev/null |
                sed -n 's|.*I2C bus: */dev/i2c-\\([0-9]*\\).*|bus \\1|p; s|.*DRM[ _]connector: *card[0-9]*-\\(.*\\)|connector \\1|p' |
                while read -r kind value; do
                    case $kind in
                        bus) bus=$value ;;
                        connector)
                            case $value in eDP*) continue ;; esac
                            vcp=$(ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null) && printf '%s\\t%s\\t%s\\n' "$value" "$bus" "$vcp" ;;
                    esac
                done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const [name, bus, vcp] = line.split("\t");
                    const match = (vcp ?? "").match(/^VCP 10 C (\d+) (\d+)/);
                    if (name && match && Number(match[2]) > 0)
                        found.push({ name: name.trim(), bus: Number(bus), level: Number(match[1]) / Number(match[2]), max: Number(match[2]) });
                }
                root.displays = found;
            }
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The laptop's backlight, whichever the machine has (intel_backlight, amdgpu_bl0, acpi_video0…):
// with several, the kernel's advice is firmware, then platform, then raw. `available` is false
// without one (a desktop, whose monitors go through ExternalBrightness instead).
Singleton {
    id: root

    // e.g. "intel_backlight" ("" until found, or without one)
    property string name: ""
    readonly property string device: name !== "" ? `/sys/class/backlight/${name}` : ""
    // The lowest it goes (5%, a step of the brightness keys), so the screen never goes fully
    // dark; brightnessctl is told the raw level
    readonly property real minFraction: 0.05
    readonly property int minRaw: Math.round(maxBrightness * minFraction)

    property int brightness: 0
    property int maxBrightness: 0
    readonly property bool available: maxBrightness > 0
    readonly property real fraction: available ? brightness / maxBrightness : 0

    // A percentage waiting for the timer below (-1 when none)
    property int pendingPercent: -1

    // Written straight away, unless the last write was under 50 ms ago (a dragged slider sends
    // many values): then the newest one waits for the 50 ms to pass
    function set(value: real): void {
        const clamped = Math.max(minFraction, Math.min(1, value));
        brightness = Math.round(clamped * maxBrightness);
        const percent = Math.round(clamped * 100);
        if (applyTimer.running) {
            pendingPercent = percent;
            return;
        }
        apply(percent);
    }

    function apply(percent: int): void {
        Exec.run(`brightnessctl --device=${Exec.quote(name)} --min-value=${minRaw} set ${percent}%`);
        pendingPercent = -1;
        applyTimer.start();
    }

    Timer {
        id: applyTimer
        interval: 50
        onTriggered: {
            if (root.pendingPercent >= 0)
                root.apply(root.pendingPercent);
        }
    }

    // sysfs doesn't send change notifications, so poll (skipped while a change is pending)
    Timer {
        interval: 500
        running: root.available
        repeat: true
        onTriggered: {
            if (root.pendingPercent < 0 && !applyTimer.running)
                brightnessFile.reload();
        }
    }

    // "type<TAB>name" per backlight; ddcci ones are monitors (the ddcci driver), not the laptop
    Process {
        running: true
        command: ["sh", "-c", `for d in /sys/class/backlight/*; do
            [ -e "$d/max_brightness" ] || continue
            case \${d##*/} in ddcci*) continue ;; esac
            printf '%s\\t%s\\n' "$(cat "$d/type")" "\${d##*/}"
        done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const rank = { firmware: 0, platform: 1, raw: 2 };
                const found = text.trim().split("\n").filter(line => line.includes("\t")).map(line => line.split("\t"));
                found.sort((a, b) => (rank[a[0]] ?? 3) - (rank[b[0]] ?? 3));
                root.name = found.length > 0 ? found[0][1] : "";
            }
        }
    }

    FileView {
        id: brightnessFile
        path: root.device !== "" ? root.device + "/brightness" : ""
        printErrors: false
        onLoaded: root.brightness = Number(text())
    }

    FileView {
        path: root.device !== "" ? root.device + "/max_brightness" : ""
        printErrors: false
        onLoaded: root.maxBrightness = Number(text())
    }
}

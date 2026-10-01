pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Laptop backlight. `available` is false on machines without intel_backlight (the desktop).
Singleton {
    id: root

    readonly property string device: "/sys/class/backlight/intel_backlight"
    // Raw level brightnessctl won't go below, same floor as the old Waybar scroll binding
    readonly property int minRaw: 10000

    property int brightness: 0
    property int maxBrightness: 0
    readonly property bool available: maxBrightness > 0
    readonly property real fraction: available ? brightness / maxBrightness : 0
    readonly property real minFraction: available ? minRaw / maxBrightness : 0

    // Latest requested percentage, applied by the debounce timer
    property int pendingPercent: -1

    function set(value: real): void {
        const clamped = Math.max(minFraction, Math.min(1, value));
        brightness = Math.round(clamped * maxBrightness);
        pendingPercent = Math.round(clamped * 100);
        applyTimer.restart();
    }

    // Slider drags fire many values; only run brightnessctl every 50ms
    Timer {
        id: applyTimer
        interval: 50
        onTriggered: {
            Exec.run(`brightnessctl --min-value=${root.minRaw} set ${root.pendingPercent}%`);
            root.pendingPercent = -1;
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

    FileView {
        id: brightnessFile
        path: root.device + "/brightness"
        printErrors: false
        onLoaded: root.brightness = Number(text())
    }

    FileView {
        path: root.device + "/max_brightness"
        printErrors: false
        onLoaded: root.maxBrightness = Number(text())
    }
}

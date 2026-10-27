pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

// Laptop battery state for the system panel. `present` is false on machines without one.
Singleton {
    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device.isLaptopBattery
    readonly property int capacity: Math.round(device.percentage * 100)
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    // On AC but held below the charge threshold
    readonly property bool plugged: device.state === UPowerDeviceState.PendingCharge

    readonly property var icons: ["\u{F007B}", "\u{F007C}", "\u{F007E}", "\u{F0080}", "\u{F0082}", "\u{F0079}"]
    readonly property string icon: charging || plugged ? "\u{F0084}" : icons[Math.min(icons.length - 1, Math.floor(capacity / 100 * icons.length))]

    // Green charging, amber at 30%, red at 20%
    readonly property color colour: {
        if (charging)
            return Theme.charging;
        if (capacity <= 20)
            return Theme.critical;
        if (capacity <= 30)
            return Theme.warning;
        return Theme.accent;
    }

    // UPower reports no time (0) for a little while after plugging in or out
    readonly property string status: {
        if (charging)
            return device.timeToFull > 0 ? `Charging, full in ${formatTime(device.timeToFull)}` : "Charging";
        if (plugged)
            return "Plugged in, not charging";
        if (!UPower.onBattery)
            return "Fully charged";
        return device.timeToEmpty > 0 ? `${formatTime(device.timeToEmpty)} remaining` : "On battery, estimating time left…";
    }

    function formatTime(seconds: real): string {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        return `${hours} h ${minutes} min`;
    }
}

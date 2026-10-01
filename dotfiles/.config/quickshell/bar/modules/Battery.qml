import QtQuick
import Quickshell.Services.UPower
import qs
import qs.components

// Hidden on machines without a battery
BarText {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property int capacity: Math.round(battery.percentage * 100)
    readonly property bool charging: battery.state === UPowerDeviceState.Charging
    // On AC but held below the charge threshold
    readonly property bool plugged: battery.state === UPowerDeviceState.PendingCharge
    readonly property var icons: ["\u{F007B}", "\u{F007C}", "\u{F007E}", "\u{F0080}", "\u{F0082}", "\u{F0079}"]
    readonly property string icon: icons[Math.min(icons.length - 1, Math.floor(capacity / 100 * icons.length))]
    function formatTime(seconds: real): string {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        return `${hours} h ${minutes} min`;
    }

    visible: battery.isLaptopBattery
    tooltip: {
        if (charging)
            return `Charging, full in ${formatTime(battery.timeToFull)}`;
        if (plugged)
            return "Plugged in, not charging";
        if (!UPower.onBattery)
            return "Fully charged";
        return `${formatTime(battery.timeToEmpty)} remaining`;
    }
    text: {
        if (charging)
            return `${capacity}% \u{F0084}`;
        if (plugged)
            return `${capacity}% \u{F0084} \u{EB2D}`;
        return `${capacity}% ${icon}`;
    }
    color: {
        if (hovered)
            return Theme.accent;
        if (charging)
            return Theme.charging;
        if (capacity <= 20)
            return Theme.critical;
        if (capacity <= 30)
            return Theme.warning;
        return Theme.text;
    }
}

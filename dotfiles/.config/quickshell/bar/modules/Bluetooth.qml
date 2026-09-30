import QtQuick
import Quickshell.Bluetooth
import qs.components
import qs.services

// Hidden when there is no Bluetooth adapter
BarText {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var connected: adapter?.devices.values.filter(d => d.connected) ?? []
    readonly property var withBattery: connected.find(d => d.batteryAvailable)

    visible: adapter !== null
    text: {
        if (!adapter?.enabled)
            return "\u{F00B2}";
        if (withBattery)
            return `${Math.round(withBattery.battery * 100)}% \u{F00AF}`;
        return "\u{F00AF}";
    }
    tooltip: {
        if (!adapter)
            return "";
        const lines = [`${adapter.name}\t${adapter.adapterId}`, "", `${connected.length} connected`];
        for (const d of connected) {
            lines.push("", d.name, d.address);
            if (d.batteryAvailable)
                lines.push(`${Math.round(d.battery * 100)}%`);
        }
        return lines.join("\n");
    }

    onLeftClicked: Exec.run("rfkill toggle bluetooth")
    onRightClicked: menu.toggle()

    ActionMenu {
        id: menu
        target: root
        items: [
            { label: "Connect", command: "rfkill unblock bluetooth" },
            { label: "Disconnect", command: "rfkill block bluetooth" },
            { separator: true },
            { label: "\u{F013} Manage connections", action: () => Exec.floating("blueman-manager", false) }
        ]
    }
}

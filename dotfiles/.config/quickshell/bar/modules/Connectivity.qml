import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import qs
import qs.components

// Network icon; the tooltip also covers Bluetooth.
// Left click opens the connectivity panel (wired up in Bar.qml).
BarText {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected)
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected)
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected)

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: adapter?.devices.values.filter(d => d.connected) ?? []

    readonly property string networkTooltip: {
        if (wifiNetwork)
            return `${wifiNetwork.name} (${Math.round(wifiNetwork.signalStrength * 100)}%)`;
        if (wired)
            return `Wired (${wired.name})`;
        return "Disconnected";
    }

    readonly property string bluetoothTooltip: {
        if (!adapter)
            return "";
        if (!adapter.enabled)
            return "Bluetooth off";
        if (btConnected.length === 0)
            return "Bluetooth on, nothing connected";
        return "Bluetooth: " + btConnected.map(d => d.batteryAvailable ? `${d.name} (${Math.round(d.battery * 100)}%)` : d.name).join(", ");
    }

    text: {
        if (wifiNetwork)
            return Theme.wifiIcon(wifiNetwork.signalStrength);
        if (wired)
            return "\u{EF09}";
        return "\u{EB01}";
    }
    tooltip: [networkTooltip, bluetoothTooltip].filter(line => line !== "").join("\n")
}

import QtQuick
import Quickshell.Networking
import qs
import qs.components

// Network icon: Wi-Fi signal strength, wired, or disconnected.
// Left click opens the connectivity panel (wired up in Bar.qml).
BarText {
    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected)
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected)
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected)

    text: {
        if (wifiNetwork)
            return Theme.wifiIcon(wifiNetwork.signalStrength);
        if (wired)
            return "\u{EF09}";
        return "\u{EB01}";
    }
}

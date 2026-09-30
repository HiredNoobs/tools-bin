import QtQuick
import Quickshell.Networking
import qs.components
import qs.services

BarText {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected)
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected)
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected)

    text: {
        if (wifiNetwork)
            return `\u{F1EB} ${wifiNetwork.name}`;
        if (wired)
            return "\u{EF09}";
        return "\u{EB01}";
    }
    tooltip: {
        if (wifiNetwork)
            return `${wifiNetwork.name} (${Math.round(wifiNetwork.signalStrength * 100)}%) \u{F1EB}`;
        if (wired)
            return `${wired.name} \u{1F5A7} `;
        return "Disconnected";
    }

    onRightClicked: menu.toggle()

    ActionMenu {
        id: menu
        target: root
        items: [
            { label: "Connect", command: "nmcli radio wifi on" },
            { label: "Disconnect", command: "nmcli radio wifi off" },
            { label: "nmtui", action: () => Exec.floating("kitty nmtui", true) },
            { separator: true },
            { label: "\u{F013} Network settings", action: () => Exec.floating("nm-connection-editor", false) }
        ]
    }
}

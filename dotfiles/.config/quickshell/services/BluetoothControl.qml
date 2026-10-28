pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth on/off and scanning, shared by the connectivity panel, Settings › Bluetooth and the
// control centre's tile, plus how a device is shown (its glyph and status line).
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    // What wants scanning for devices (the panel, the settings page). The adapter scans while
    // anything does, so one closing doesn't stop the other's scan; a scan already going when
    // the first asked (bluetoothctl) is left running when the last lets go.
    property var holders: []
    property bool startedScan: false

    // The adapter can't power on while rfkill blocks it (airplane mode): unblock it, then
    // switch on once it has come back
    function setPowered(on: bool): void {
        if (!adapter)
            return;
        if (on && adapter.state === BluetoothAdapterState.Blocked) {
            Exec.run("rfkill unblock bluetooth");
            powerAfterUnblock.restart();
            return;
        }
        adapter.enabled = on;
    }

    function setDiscovering(holder: var, on: bool): void {
        holders = [...holders.filter(h => h !== holder), ...(on ? [holder] : [])];
        applyDiscovering();
    }

    // The scan button: stops scanning whoever started it, or starts it for `holder`
    function toggleDiscovering(holder: var): void {
        if (adapter?.discovering) {
            holders = [];
            startedScan = false;
            adapter.discovering = false;
        } else {
            setDiscovering(holder, true);
        }
    }

    function applyDiscovering(): void {
        if (!adapter)
            return;
        if (holders.length > 0 && !adapter.discovering) {
            adapter.discovering = true;
            startedScan = true;
        } else if (holders.length === 0 && startedScan) {
            adapter.discovering = false;
            startedScan = false;
        }
    }

    // BlueZ's device icon names to glyphs
    function deviceIcon(device: BluetoothDevice): string {
        const icon = device?.icon ?? "";
        if (icon.includes("headset") || icon.includes("headphone"))
            return "\u{F02CB}";
        if (icon.startsWith("audio"))
            return "\u{F04C3}";
        if (icon.includes("keyboard"))
            return "\u{F030C}";
        if (icon.includes("mouse"))
            return "\u{F037D}";
        if (icon.includes("gaming"))
            return "\u{F0297}";
        if (icon.includes("phone"))
            return "\u{F011C}";
        if (icon.includes("computer"))
            return "\u{F0322}";
        if (icon.includes("display") || icon.includes("video"))
            return "\u{F0379}";
        return "\u{F00AF}";
    }

    function status(device: BluetoothDevice): string {
        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        }
        if (!device.connected)
            return adapter?.enabled ? "Not connected" : "Bluetooth is off";
        return device.batteryAvailable ? `Connected · battery ${Math.round(device.battery * 100)}%` : "Connected";
    }

    Timer {
        id: powerAfterUnblock
        interval: 800
        onTriggered: {
            if (root.adapter)
                root.adapter.enabled = true;
        }
    }
}

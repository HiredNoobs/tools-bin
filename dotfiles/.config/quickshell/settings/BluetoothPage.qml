import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

// Settings › Bluetooth, in place of blueman: on/off, this computer's name and visibility,
// paired devices (connect, battery, trust, block, rename, forget) and scanning for new ones to
// pair. Through Quickshell's BlueZ support; only renaming the adapter goes through busctl.
Column {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices.values ?? []
    // Connected first, then by name
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")

    // Devices opened here stay open for the session (PanelState); forgotten ones are dropped
    readonly property var deviceKeys: paired.map(d => `bluetooth:${d.address}`)
    onDeviceKeysChanged: {
        if (deviceKeys.length > 0)
            PanelState.pruneByPrefix("settings", "bluetooth:", deviceKeys);
    }

    spacing: 24

    // A scan started here stops when leaving the page, unless the panel is scanning too
    Component.onDestruction: BluetoothControl.setDiscovering(root, false)

    SettingRow {
        visible: root.adapter === null
        label: "No Bluetooth adapter found"
    }

    SettingsGroup {
        visible: root.adapter !== null
        title: "This computer"

        ToggleRow {
            label: "Bluetooth"
            description: root.adapter?.state === BluetoothAdapterState.Blocked ? "Blocked (airplane mode or a hardware switch); switching on unblocks it." : ""
            checked: root.on
            onToggled: on => BluetoothControl.setPowered(on)
        }

        SettingRow {
            enabled: root.on
            label: "Name"
            description: "What other devices see when they look for this one."

            Row {
                spacing: 8

                CommitField {
                    id: adapterName
                    width: 220
                    value: root.adapter?.name ?? ""
                    onCommitted: name => Exec.run(`busctl --system set-property org.bluez ${Exec.quote(root.adapter.dbusPath)} org.bluez.Adapter1 Alias s ${Exec.quote(name)}`)
                }

                PanelButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: adapterName.edited && adapterName.text.trim() !== ""
                    label: "Rename"
                    highlighted: true
                    onClicked: adapterName.commit()
                }
            }
        }

        ToggleRow {
            enabled: root.on
            label: "Visible to other devices"
            description: "So a phone or another computer can find this one to pair. Turns itself off after a few minutes."
            checked: root.adapter?.discoverable ?? false
            onToggled: on => root.adapter.discoverable = on
        }
    }

    // Listed while Bluetooth is off too, to rename or forget them
    SettingsGroup {
        visible: root.adapter !== null
        title: "My devices"

        Repeater {
            model: root.paired

            DeviceBlock {
                required property BluetoothDevice modelData
                device: modelData
            }
        }

        SettingRow {
            visible: root.paired.length === 0
            label: "No paired devices"
            description: root.on ? "Scan below to pair one." : "Switch Bluetooth on to pair one."
        }
    }

    SettingsGroup {
        visible: root.adapter !== null && root.on
        title: "Pair a new device"

        SettingRow {
            label: root.adapter?.discovering ? "Scanning…" : "Scan for devices"
            description: "Put the device in pairing mode first (often by holding its power or Bluetooth button)."

            PanelButton {
                icon: "\u{F002}"
                label: root.adapter?.discovering ? "Stop" : "Scan"
                highlighted: root.adapter?.discovering ?? false
                onClicked: BluetoothControl.toggleDiscovering(root)
            }
        }

        // While scanning, and a device still pairing after it stops (so it can be cancelled)
        Repeater {
            model: ScriptModel {
                values: root.adapter?.discovering ? root.nearby : root.nearby.filter(d => d.pairing)
            }

            SettingRow {
                required property BluetoothDevice modelData
                label: `${BluetoothControl.deviceIcon(modelData)}  ${modelData.deviceName}`
                description: modelData.pairing ? "Pairing…" : modelData.address

                PanelButton {
                    label: modelData.pairing ? "Cancel" : "Pair"
                    onClicked: modelData.pairing ? modelData.cancelPair() : modelData.pair()
                }
            }
        }
    }

    // A paired device: icon, name and status with Connect / Disconnect, expanding (remembered
    // for the session) to trust, block, rename and forget
    component DeviceBlock: SettingsBlock {
        id: block

        property BluetoothDevice device
        readonly property bool busy: device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting

        spacing: 12

        BlockHeader {
            id: header
            title: `${BluetoothControl.deviceIcon(block.device)}  ${block.device.name}`
            detail: BluetoothControl.status(block.device)
            accent: block.device.connected
            expandable: true
            stateKey: `bluetooth:${block.device.address}`

            PanelButton {
                enabled: !block.busy && root.on
                opacity: enabled ? 1 : 0.4
                label: block.device.connected ? "Disconnect" : "Connect"
                onClicked: block.device.connected ? block.device.disconnect() : block.device.connect()
            }
        }

        Column {
            visible: header.expanded
            width: parent.width
            spacing: 12

            InlineOption {
                label: "Trusted"
                description: "Can connect without asking."

                Toggle {
                    checked: block.device.trusted
                    onToggled: block.device.trusted = !checked
                }
            }

            InlineOption {
                label: "Blocked"
                description: "Refuses all connections from it."

                Toggle {
                    checked: block.device.blocked
                    onToggled: block.device.blocked = !checked
                }
            }

            InlineOption {
                label: "Name"
                description: block.device.deviceName !== block.device.name ? `Calls itself "${block.device.deviceName}"` : ""

                Row {
                    spacing: 8

                    CommitField {
                        id: deviceName
                        width: 200
                        value: block.device.name
                        onCommitted: name => block.device.name = name
                    }

                    PanelButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: deviceName.edited && deviceName.text.trim() !== ""
                        label: "Rename"
                        highlighted: true
                        onClicked: deviceName.commit()
                    }
                }
            }

            Row {
                spacing: 12

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: block.device.address
                    dim: true
                }

                ConfirmButton {
                    text: "Forget"
                    onConfirmed: block.device.forget()
                }
            }
        }
    }
}

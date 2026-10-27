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
    // Scanning was started here (not from the connectivity panel), so leaving stops it
    property bool startedDiscovery: false

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
            return root.on ? "Not connected" : "Bluetooth is off";
        return device.batteryAvailable ? `Connected · battery ${Math.round(device.battery * 100)}%` : "Connected";
    }

    function setPower(on: bool): void {
        if (!adapter)
            return;
        // The adapter can't power on while rfkill blocks it
        if (on && adapter.state === BluetoothAdapterState.Blocked) {
            Exec.run("rfkill unblock bluetooth");
            powerAfterUnblock.restart();
            return;
        }
        adapter.enabled = on;
    }

    spacing: 24

    // Stop scanning when leaving the page
    Component.onDestruction: {
        if (startedDiscovery && adapter?.discovering)
            adapter.discovering = false;
    }

    Timer {
        id: powerAfterUnblock
        interval: 500
        onTriggered: {
            if (root.adapter)
                root.adapter.enabled = true;
        }
    }

    SettingRow {
        visible: root.adapter === null
        label: "No Bluetooth adapter found"
    }

    SettingsGroup {
        visible: root.adapter !== null
        title: "This computer"

        SettingRow {
            label: "Bluetooth"
            description: root.adapter?.state === BluetoothAdapterState.Blocked ? "Blocked (airplane mode or a hardware switch); switching on unblocks it." : ""

            Toggle {
                checked: root.on
                onToggled: root.setPower(!checked)
            }
        }

        SettingRow {
            enabled: root.on
            label: "Name"
            description: "What other devices see when they look for this one."

            Row {
                spacing: 8

                TextField {
                    id: adapterName
                    width: 220
                    text: root.adapter?.name ?? ""
                    onAccepted: rename.clicked()
                }

                PanelButton {
                    id: rename
                    anchors.verticalCenter: parent.verticalCenter
                    visible: adapterName.text.trim() !== "" && adapterName.text.trim() !== (root.adapter?.name ?? "")
                    label: "Rename"
                    highlighted: true
                    onClicked: Exec.run(`busctl --system set-property org.bluez ${Exec.quote(root.adapter.dbusPath)} org.bluez.Adapter1 Alias s ${Exec.quote(adapterName.text.trim())}`)
                }
            }
        }

        SettingRow {
            enabled: root.on
            label: "Visible to other devices"
            description: "So a phone or another computer can find this one to pair. Turns itself off after a few minutes."

            Toggle {
                checked: root.adapter?.discoverable ?? false
                onToggled: root.adapter.discoverable = !checked
            }
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
                onClicked: {
                    root.startedDiscovery = !root.adapter.discovering;
                    root.adapter.discovering = !root.adapter.discovering;
                }
            }
        }

        // While scanning, and a device still pairing after it stops (so it can be cancelled)
        Repeater {
            model: ScriptModel {
                values: root.adapter?.discovering ? root.nearby : root.nearby.filter(d => d.pairing)
            }

            SettingRow {
                required property BluetoothDevice modelData
                label: `${root.deviceIcon(modelData)}  ${modelData.deviceName}`
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
    component DeviceBlock: Item {
        id: block

        property BluetoothDevice device
        readonly property bool busy: device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting
        readonly property string stateKey: `bluetooth:${device.address}`
        readonly property bool expanded: PanelState.isOpen("settings", stateKey)
        property bool forgetArmed: false

        width: parent?.width ?? 0
        implicitHeight: column.implicitHeight + 28

        Column {
            id: column
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 12

            Item {
                width: parent.width
                height: Math.max(title.implicitHeight, connectButton.height)

                PanelText {
                    id: title
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - connectButton.width - chevron.width - 24
                    text: `${root.deviceIcon(block.device)}  ${block.device.name}  ·  ${root.status(block.device)}`
                    elide: Text.ElideRight
                    color: block.device.connected ? Theme.accent : Theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: connectButton.width + chevron.width + 16
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PanelState.toggle("settings", block.stateKey)
                }

                PanelButton {
                    id: connectButton
                    anchors.right: chevron.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !block.busy && root.on
                    opacity: enabled ? 1 : 0.4
                    label: block.device.connected ? "Disconnect" : "Connect"
                    onClicked: block.device.connected ? block.device.disconnect() : block.device.connect()
                }

                PanelText {
                    id: chevron
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    horizontalAlignment: Text.AlignRight
                    text: block.expanded ? "\u{F077}" : "\u{F078}"
                    color: block.expanded ? Theme.accent : Theme.subtext
                    font.pixelSize: Theme.panelFontSize - 3

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PanelState.toggle("settings", block.stateKey)
                    }
                }
            }

            Column {
                visible: block.expanded
                width: parent.width
                spacing: 12

                Option {
                    label: "Trusted"
                    description: "Can connect without asking."

                    Toggle {
                        checked: block.device.trusted
                        onToggled: block.device.trusted = !checked
                    }
                }

                Option {
                    label: "Blocked"
                    description: "Refuses all connections from it."

                    Toggle {
                        checked: block.device.blocked
                        onToggled: block.device.blocked = !checked
                    }
                }

                Option {
                    label: "Name"
                    description: block.device.deviceName !== block.device.name ? `Calls itself "${block.device.deviceName}"` : ""

                    Row {
                        spacing: 8

                        TextField {
                            id: deviceName
                            width: 200
                            text: block.device.name
                            onAccepted: renameDevice.clicked()
                        }

                        PanelButton {
                            id: renameDevice
                            anchors.verticalCenter: parent.verticalCenter
                            visible: deviceName.text.trim() !== "" && deviceName.text.trim() !== block.device.name
                            label: "Rename"
                            highlighted: true
                            onClicked: block.device.name = deviceName.text.trim()
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

                    // Twice, within 3 seconds
                    PanelButton {
                        label: block.forgetArmed ? "Forget? Click again" : "Forget"
                        highlighted: block.forgetArmed
                        onClicked: {
                            if (block.forgetArmed)
                                block.device.forget();
                            block.forgetArmed = !block.forgetArmed;
                            disarm.restart();
                        }
                    }
                }
            }
        }

        Timer {
            id: disarm
            interval: 3000
            onTriggered: block.forgetArmed = false
        }
    }

    // A label (and dim description) on the left and its control on the right
    component Option: Item {
        property string label
        property string description: ""
        default property alias control: controlArea.data

        width: parent.width
        implicitHeight: Math.max(optionText.implicitHeight, controlArea.childrenRect.height)

        Column {
            id: optionText
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - controlArea.width - 16
            spacing: 2

            PanelText {
                text: parent.parent.label
            }

            PanelText {
                visible: text !== ""
                width: parent.width
                text: parent.parent.description
                wrapMode: Text.WordWrap
                dim: true
                font.pixelSize: Theme.panelFontSize - 1
            }
        }

        Item {
            id: controlArea
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}

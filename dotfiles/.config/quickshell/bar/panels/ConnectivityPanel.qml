import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import qs
import qs.components
import qs.services

// Opened from the network icon: Wi-Fi and Bluetooth
Column {
    id: root

    signal closeRequested

    // Wi-Fi
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var networks: {
        const list = wifiDevice?.networks.values.filter(n => n.name !== "") ?? [];
        return list.sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
    }
    // Network waiting for a password, if any
    property var passwordNetwork: null

    // Bluetooth
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    readonly property var btDevices: adapter?.devices.values ?? []
    readonly property var pairedDevices: btDevices.filter(d => d.paired || d.bonded)
    readonly property var newDevices: btDevices.filter(d => !d.paired && !d.bonded && d.name !== "")

    function connectTo(network: var): void {
        if (network.connected)
            return;
        // Clicking the network again hides its password field
        if (passwordNetwork === network) {
            passwordNetwork = null;
            return;
        }
        if (network.known || network.security === WifiSecurityType.Open) {
            passwordNetwork = null;
            network.connect();
        } else {
            passwordNetwork = network;
        }
    }

    function setBluetooth(on: bool): void {
        if (!adapter)
            return;
        // The adapter can't power on while rfkill blocks it
        if (on && adapter.state === BluetoothAdapterState.Blocked) {
            Exec.run("rfkill unblock bluetooth");
            enableAfterUnblock.restart();
            return;
        }
        adapter.enabled = on;
    }

    function run(action: var): void {
        action();
        closeRequested();
    }

    width: 360
    spacing: 10

    // Scan only while the panel is open
    Component.onCompleted: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = true;
    }
    Component.onDestruction: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = false;
        if (adapter?.discovering)
            adapter.discovering = false;
    }

    Timer {
        id: enableAfterUnblock
        interval: 800
        onTriggered: {
            if (root.adapter)
                root.adapter.enabled = true;
        }
    }

    // --- Wi-Fi ---

    SectionHeader {
        visible: root.wifiDevice !== null
        text: "Wi-Fi"
        checked: Networking.wifiEnabled
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    PanelText {
        visible: root.wifiDevice !== null && !Networking.wifiHardwareEnabled
        text: "Wi-Fi is blocked by a hardware switch"
        dim: true
    }

    // Network list, scrollable when long
    Flickable {
        visible: root.wifiDevice !== null && Networking.wifiEnabled
        width: parent.width
        height: Math.min(networkColumn.implicitHeight, 280)
        contentHeight: networkColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: networkColumn
            width: parent.width
            spacing: 2

            PanelText {
                visible: root.networks.length === 0
                text: "Searching…"
                dim: true
            }

            Repeater {
                model: root.networks

                Column {
                    id: networkEntry

                    required property var modelData
                    readonly property bool secured: modelData.security !== WifiSecurityType.Open
                    readonly property bool connecting: modelData.state === ConnectionState.Connecting
                    readonly property bool askingPassword: root.passwordNetwork === modelData

                    width: networkColumn.width
                    spacing: 4

                    ListRow {
                        width: parent.width
                        icon: Theme.wifiIcon(networkEntry.modelData.signalStrength)
                        label: networkEntry.modelData.name
                        sublabel: {
                            if (networkEntry.modelData.connected)
                                return "Connected";
                            if (networkEntry.connecting)
                                return "Connecting…";
                            if (networkEntry.modelData.known)
                                return "Saved";
                            return networkEntry.secured ? "Secured" : "Open";
                        }
                        selected: networkEntry.modelData.connected
                        onClicked: root.connectTo(networkEntry.modelData)

                        Row {
                            spacing: 8

                            PanelText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: networkEntry.secured && !networkEntry.modelData.connected
                                text: "\u{F023}"
                                dim: true
                            }

                            PanelButton {
                                visible: networkEntry.modelData.connected
                                label: "Disconnect"
                                onClicked: networkEntry.modelData.disconnect()
                            }
                        }
                    }

                    PasswordField {
                        visible: networkEntry.askingPassword
                        width: parent.width
                        network: networkEntry.modelData
                    }

                    // A saved password that no longer works asks again
                    Connections {
                        target: networkEntry.modelData
                        function onConnectionFailed(reason) {
                            if (reason === ConnectionFailReason.NoSecrets)
                                root.passwordNetwork = networkEntry.modelData;
                        }
                    }
                }
            }
        }
    }

    ListRow {
        visible: root.wiredDevice?.hasLink ?? false
        width: parent.width
        clickable: false
        icon: "\u{EF09}"
        label: "Wired"
        sublabel: root.wiredDevice?.connected ? `Connected, ${root.wiredDevice.linkSpeed} Mb/s` : "Cable plugged in, not connected"
        selected: root.wiredDevice?.connected ?? false
    }

    Row {
        spacing: 8

        PanelButton {
            label: "nmtui"
            onClicked: root.run(() => Exec.floating("kitty nmtui", true))
        }

        PanelButton {
            icon: "\u{F013}"
            label: "Network settings"
            onClicked: root.run(() => Exec.run("qs ipc call settings open network"))
        }
    }

    // --- Bluetooth ---

    SectionHeader {
        visible: root.adapter !== null
        text: "Bluetooth"
        checked: root.bluetoothOn
        onToggled: root.setBluetooth(!root.bluetoothOn)
    }

    Column {
        visible: root.bluetoothOn
        width: parent.width
        spacing: 2

        PanelText {
            visible: root.pairedDevices.length === 0
            text: "No paired devices"
            dim: true
        }

        Repeater {
            model: root.pairedDevices

            ListRow {
                id: deviceRow

                required property BluetoothDevice modelData
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

                width: parent.width
                icon: "\u{F00AF}"
                label: modelData.name
                sublabel: {
                    if (modelData.state === BluetoothDeviceState.Connecting)
                        return "Connecting…";
                    if (modelData.state === BluetoothDeviceState.Disconnecting)
                        return "Disconnecting…";
                    if (!modelData.connected)
                        return "Not connected";
                    return modelData.batteryAvailable ? `Connected, battery ${Math.round(modelData.battery * 100)}%` : "Connected";
                }
                selected: modelData.connected
                clickable: !busy
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()

                PanelButton {
                    icon: "\u{F1F8}"
                    onClicked: deviceRow.modelData.forget()
                }
            }
        }

        // Scanning shows devices that can be paired
        Item {
            width: parent.width
            height: 6
        }

        PanelButton {
            icon: "\u{F002}"
            label: root.adapter?.discovering ? "Stop scanning" : "Scan for devices"
            highlighted: root.adapter?.discovering ?? false
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }

        Repeater {
            model: root.adapter?.discovering ? root.newDevices : []

            ListRow {
                id: newDeviceRow

                required property BluetoothDevice modelData

                width: parent.width
                icon: "\u{F00AF}"
                label: modelData.name
                sublabel: modelData.pairing ? "Pairing…" : "Available"
                clickable: false

                PanelButton {
                    visible: !newDeviceRow.modelData.pairing
                    label: "Pair"
                    onClicked: newDeviceRow.modelData.pair()
                }
            }
        }
    }

    PanelButton {
        visible: root.adapter !== null
        icon: "\u{F013}"
        label: "Bluetooth settings"
        onClicked: root.run(() => Exec.run("qs ipc call settings open bluetooth"))
    }

    // Section heading with an on/off switch on the right
    component SectionHeader: Item {
        id: header

        property alias text: title.text
        property alias checked: toggle.checked
        signal toggled

        width: root.width
        height: Math.max(title.implicitHeight, toggle.implicitHeight)

        PanelSection {
            id: title
            anchors.verticalCenter: parent.verticalCenter
        }

        Toggle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onToggled: header.toggled()
        }
    }

    // Password entry shown under a secured network; Enter connects
    component PasswordField: Row {
        id: field

        property var network

        spacing: 8

        onVisibleChanged: {
            if (visible) {
                input.text = "";
                input.forceActiveFocus();
            }
        }

        function submit(): void {
            if (input.text === "")
                return;
            field.network.connectWithPsk(input.text);
            input.text = "";
            root.passwordNetwork = null;
        }

        Rectangle {
            width: field.width - connectButton.width - field.spacing
            height: connectButton.height
            radius: 8
            color: Theme.surface
            border.width: input.activeFocus ? 1 : 0
            border.color: Theme.accent

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelFontSize
                clip: true
                onAccepted: field.submit()

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Password"
                    dim: true
                }
            }
        }

        PanelButton {
            id: connectButton
            label: "Connect"
            onClicked: field.submit()
        }
    }
}

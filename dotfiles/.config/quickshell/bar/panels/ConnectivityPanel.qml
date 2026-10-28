import QtQuick
import Quickshell
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
    // Connected first, then by signal in whole bars (so rows don't swap places with every
    // small change while scanning), then by name
    readonly property var networks: {
        const list = wifiDevice?.networks.values.filter(n => n.name !== "") ?? [];
        const bars = n => Math.round(n.signalStrength * 4);
        return list.sort((a, b) => (b.connected - a.connected) || (bars(b) - bars(a)) || a.name.localeCompare(b.name));
    }
    // Network waiting for a password, if any
    property var passwordNetwork: null

    // Bluetooth
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    readonly property var btDevices: adapter?.devices.values ?? []
    readonly property var pairedDevices: btDevices.filter(d => d.paired || d.bonded)
    readonly property var newDevices: btDevices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")

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

    function run(action: var): void {
        action();
        closeRequested();
    }

    width: 360
    spacing: 10

    // Scan only while the panel is open (as well as anything else scanning), also with a Wi-Fi
    // device that turns up meanwhile. A Bluetooth scan started here stops on closing, unless
    // Settings › Bluetooth is scanning too.
    onWifiDeviceChanged: NetworkConnections.setScanning(root, wifiDevice)
    Component.onCompleted: NetworkConnections.setScanning(root, wifiDevice)
    Component.onDestruction: {
        NetworkConnections.setScanning(root, null);
        BluetoothControl.setDiscovering(root, false);
    }

    // --- Wi-Fi ---

    PanelHeading {
        visible: root.wifiDevice !== null
        text: "Wi-Fi"

        Toggle {
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    PanelText {
        visible: root.wifiDevice !== null && !Networking.wifiHardwareEnabled
        text: "Wi-Fi is blocked by a hardware switch"
        dim: true
    }

    // Network list, scrollable when long
    Flickable {
        id: networkList
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
                // Rows are kept for the same networks (not made again with each scan, which
                // would lose a password being typed)
                model: ScriptModel {
                    values: root.networks
                }

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

                    WifiPasswordField {
                        visible: networkEntry.askingPassword
                        width: parent.width
                        fill: true
                        network: networkEntry.modelData
                        onSubmitted: root.passwordNetwork = null
                        onCancelled: root.passwordNetwork = null
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

    ScrollIndicator {
        flickable: networkList
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

    PanelHeading {
        visible: root.adapter !== null
        text: "Bluetooth"

        Toggle {
            checked: root.bluetoothOn
            onToggled: BluetoothControl.setPowered(!root.bluetoothOn)
        }
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
            model: ScriptModel {
                values: root.pairedDevices
            }

            ListRow {
                id: deviceRow

                required property BluetoothDevice modelData
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

                width: parent.width
                icon: BluetoothControl.deviceIcon(modelData)
                label: modelData.name
                sublabel: BluetoothControl.status(modelData)
                selected: modelData.connected
                clickable: !busy
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()

                // Twice, within 3 seconds
                ConfirmButton {
                    icon: "\u{F1F8}"
                    text: "Forget"
                    armedLabel: "Forget?"
                    iconOnly: true
                    onConfirmed: deviceRow.modelData.forget()
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
            onClicked: BluetoothControl.toggleDiscovering(root)
        }

        // While scanning, and a device still pairing after it stops
        Repeater {
            model: ScriptModel {
                values: root.adapter?.discovering ? root.newDevices : root.newDevices.filter(d => d.pairing)
            }

            ListRow {
                id: newDeviceRow

                required property BluetoothDevice modelData

                width: parent.width
                icon: BluetoothControl.deviceIcon(modelData)
                label: modelData.deviceName
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
}

import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.components
import qs.services

// Settings › Network, in place of nm-connection-editor: Wi-Fi on/off and the current
// connection's details, networks in range to connect to, saved networks (in range or not)
// with auto-connect, IP and DNS settings, hidden networks, wired connections, and WireGuard
// VPNs (imported from a .conf file). Saved connections and their settings go through nmcli
// (NetworkConnections), re-read every few seconds while open.
Column {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var currentNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property var inRange: wifiDevice?.networks.values.map(n => n.name) ?? []

    // Saved Wi-Fi networks: connected first, then most recently used
    readonly property var savedWifi: NetworkConnections.connections
        .filter(c => c.type === "802-11-wireless")
        .sort((a, b) => (b.active - a.active) || (b.lastUsed - a.lastUsed))
    readonly property var savedWired: NetworkConnections.connections.filter(c => c.type === "802-3-ethernet")
    readonly property var wireguard: NetworkConnections.connections.filter(c => c.type === "wireguard")
    // Networks in range not saved yet, strongest first
    readonly property var available: (wifiDevice?.networks.values ?? [])
        .filter(n => n.name !== "" && !n.known && !n.connected)
        .sort((a, b) => b.signalStrength - a.signalStrength)
    // The network whose password field is open
    property var passwordNetwork: null

    function connectTo(network: var): void {
        if (network.security === WifiSecurityType.Open) {
            passwordNetwork = null;
            network.connect();
        } else {
            passwordNetwork = passwordNetwork === network ? null : network;
        }
    }

    function ago(ms: real): string {
        if (ms <= 0)
            return "Never used";
        const minutes = (Date.now() - ms) / 60000;
        if (minutes < 60)
            return "Used just now";
        if (minutes < 60 * 24)
            return `Used ${Math.round(minutes / 60)} h ago`;
        const days = Math.round(minutes / (60 * 24));
        return days === 1 ? "Used yesterday" : `Used ${days} days ago`;
    }

    spacing: 24

    // Scan for networks while the page is open
    Component.onCompleted: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = true;
    }
    Component.onDestruction: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = false;
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: NetworkConnections.refresh()
    }

    // An action that failed (wrong password, bad address…)
    Rectangle {
        visible: NetworkConnections.error !== ""
        width: parent.width
        height: errorText.implicitHeight + 20
        radius: Theme.radius
        color: Qt.alpha(Theme.critical, 0.15)

        PanelText {
            id: errorText
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 28
            text: `\u{F0026}  ${NetworkConnections.error}`
            wrapMode: Text.WordWrap
            color: Theme.critical
        }
    }

    SettingsGroup {
        visible: root.wifiDevice !== null
        title: "Wi-Fi"

        SettingRow {
            label: "Wi-Fi"
            description: !Networking.wifiHardwareEnabled ? "Switched off by the hardware switch or airplane mode key." : ""

            Toggle {
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        // The network connected to now, and its details
        Block {
            visible: root.currentNetwork !== null

            Header {
                title: root.currentNetwork?.name ?? ""
                detail: "Connected"
                accent: true

                PanelButton {
                    label: "Disconnect"
                    onClicked: root.currentNetwork?.disconnect()
                }
            }

            DeviceDetails {
                device: root.wifiDevice?.name ?? ""
                wifi: true
            }
        }
    }

    SettingsGroup {
        visible: root.wifiDevice !== null && Networking.wifiEnabled
        title: "Available networks"

        Repeater {
            model: root.available

            Block {
                id: availableBlock

                required property var modelData
                readonly property bool secured: modelData.security !== WifiSecurityType.Open
                readonly property bool connecting: modelData.state === ConnectionState.Connecting
                readonly property bool askingPassword: root.passwordNetwork === modelData

                function submit(): void {
                    if (passwordField.text === "")
                        return;
                    modelData.connectWithPsk(passwordField.text);
                    passwordField.text = "";
                    root.passwordNetwork = null;
                }

                Header {
                    title: availableBlock.modelData.name
                    detail: availableBlock.connecting ? "Connecting…" : `${availableBlock.secured ? "\u{F023}  Secured" : "Open"} · ${Math.round(availableBlock.modelData.signalStrength * 100)}%`

                    PanelButton {
                        visible: !availableBlock.connecting
                        label: availableBlock.askingPassword ? "Cancel" : "Connect"
                        onClicked: root.connectTo(availableBlock.modelData)
                    }
                }

                Row {
                    visible: availableBlock.askingPassword
                    spacing: 8

                    onVisibleChanged: {
                        if (visible) {
                            passwordField.text = "";
                            passwordField.forceActiveFocus();
                        }
                    }

                    TextField {
                        id: passwordField
                        width: 300
                        placeholder: "Password"
                        password: true
                        onAccepted: availableBlock.submit()
                    }

                    PanelButton {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Connect"
                        highlighted: true
                        enabled: passwordField.text !== ""
                        opacity: enabled ? 1 : 0.4
                        onClicked: availableBlock.submit()
                    }
                }

                Connections {
                    target: availableBlock.modelData
                    function onConnectionFailed(reason) {
                        NetworkConnections.error = `Couldn't connect to ${availableBlock.modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                    }
                }
            }
        }

        SettingRow {
            visible: root.available.length === 0
            label: "Searching…"
            description: "Networks in range that you haven't connected to before show up here."
        }
    }

    SettingsGroup {
        visible: root.wifiDevice !== null
        title: "Saved networks"

        Repeater {
            model: root.savedWifi

            ConnectionBlock {
                required property var modelData
                connection: modelData
                status: modelData.active ? "Connected" : root.inRange.includes(modelData.name) ? "In range" : root.ago(modelData.lastUsed)
                canConnect: !modelData.active && root.inRange.includes(modelData.name)
            }
        }

        SettingRow {
            visible: root.savedWifi.length === 0
            label: "No saved networks"
            description: "Networks you connect to from the bar are saved here."
        }
    }

    SettingsGroup {
        visible: root.wifiDevice !== null
        title: "Hidden network"

        Block {
            id: hidden

            function submit(): void {
                if (ssid.text.trim() === "")
                    return;
                NetworkConnections.connectHidden(ssid.text.trim(), password.text);
                ssid.text = "";
                password.text = "";
            }

            PanelText {
                width: parent.width
                text: "Networks that don't broadcast their name. Leave the password empty for an open network."
                wrapMode: Text.WordWrap
                dim: true
                font.pixelSize: Theme.panelFontSize - 1
            }

            Row {
                spacing: 8

                TextField {
                    id: ssid
                    width: 220
                    placeholder: "Network name"
                    onAccepted: password.forceActiveFocus()
                }

                TextField {
                    id: password
                    width: 220
                    placeholder: "Password"
                    password: true
                    onAccepted: hidden.submit()
                }

                PanelButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Connect"
                    enabled: ssid.text.trim() !== ""
                    opacity: enabled ? 1 : 0.4
                    onClicked: hidden.submit()
                }
            }
        }
    }

    SettingsGroup {
        visible: root.wiredDevice !== null
        title: "Wired"

        Block {
            id: wired

            readonly property bool connected: root.wiredDevice?.connected ?? false

            Header {
                title: root.wiredDevice?.name ?? ""
                detail: wired.connected ? "Connected" : (root.wiredDevice?.hasLink ?? false) ? "Cable plugged in, not connected" : "Cable unplugged"
                accent: wired.connected
            }

            DeviceDetails {
                visible: wired.connected
                device: root.wiredDevice?.name ?? ""
            }
        }

        Repeater {
            model: root.savedWired

            ConnectionBlock {
                required property var modelData
                connection: modelData
                status: modelData.active ? "Connected" : root.ago(modelData.lastUsed)
                canConnect: !modelData.active && (root.wiredDevice?.hasLink ?? false)
            }
        }
    }

    SettingsGroup {
        title: "WireGuard VPN"

        Repeater {
            model: root.wireguard

            ConnectionBlock {
                required property var modelData
                connection: modelData
                vpn: true
                status: modelData.active ? "Connected" : "Off"
            }
        }

        Block {
            id: importer

            function submit(): void {
                if (path.text.trim() === "")
                    return;
                NetworkConnections.importWireguard(path.text.trim());
                path.text = "";
            }

            PanelText {
                width: parent.width
                text: "Import a WireGuard config (.conf) from your VPN provider or server. It's named after the file and starts off; switch it on above."
                wrapMode: Text.WordWrap
                dim: true
                font.pixelSize: Theme.panelFontSize - 1
            }

            Row {
                spacing: 8

                TextField {
                    id: path
                    width: 340
                    placeholder: "~/Downloads/wg0.conf"
                    onAccepted: importer.submit()
                }

                PanelButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Browse…"
                    onClicked: fileDialog.open()
                }

                PanelButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Import"
                    highlighted: path.text.trim() !== ""
                    enabled: path.text.trim() !== ""
                    opacity: enabled ? 1 : 0.4
                    onClicked: importer.submit()
                }
            }

            FileDialog {
                id: fileDialog
                title: "WireGuard config"
                nameFilters: ["WireGuard config (*.conf)", "All files (*)"]
                currentFolder: `file://${Quickshell.env("HOME")}/Downloads`
                onAccepted: path.text = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            }
        }
    }

    // A block of rows inside a SettingsGroup, padded like a SettingRow
    component Block: Item {
        default property alias content: column.data

        width: parent?.width ?? 0
        implicitHeight: column.implicitHeight + 28

        Column {
            id: column
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 10
        }
    }

    // Title and dim detail on the left, buttons on the right
    component Header: Item {
        id: header

        property string title
        property string detail: ""
        property bool accent: false
        default property alias trailing: trailingArea.data

        width: parent.width
        implicitHeight: Math.max(titleText.implicitHeight, trailingArea.childrenRect.height)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - trailingArea.width - 16
            spacing: 8

            PanelText {
                id: titleText
                width: Math.min(implicitWidth, parent.width)
                text: header.title
                elide: Text.ElideRight
                color: header.accent ? Theme.accent : Theme.text
            }

            PanelText {
                visible: header.detail !== ""
                width: parent.width - titleText.width - parent.spacing
                text: `·  ${header.detail}`
                elide: Text.ElideRight
                dim: true
            }
        }

        Row {
            id: trailingArea
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }

    // A label and its value, for details
    component Detail: Row {
        property string label
        property string value

        visible: value !== ""
        spacing: 12

        PanelText {
            width: 120
            text: parent.label
            dim: true
        }

        PanelText {
            text: parent.value
        }
    }

    // A device's live details from nmcli: addresses, and for Wi-Fi the band and speed
    component DeviceDetails: Column {
        id: details

        property string device
        property bool wifi: false
        property var info: ({})
        property var radio: ({})

        readonly property var addresses: info["IP4.ADDRESS"] ?? []
        readonly property var dns: info["IP4.DNS"] ?? []

        width: parent.width
        spacing: 4

        Timer {
            interval: 4000
            running: details.visible && details.device !== ""
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                deviceShow.running = true;
                if (details.wifi)
                    wifiList.running = true;
            }
        }

        Process {
            id: deviceShow
            command: ["nmcli", "-t", "-f", "GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show", details.device]
            stdout: StdioCollector {
                onStreamFinished: details.info = NetworkConnections.parseShow(text)
            }
        }

        // The connected network's line from the scan list (marked "*")
        Process {
            id: wifiList
            command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,CHAN,FREQ,RATE,SECURITY", "device", "wifi", "list", "ifname", details.device, "--rescan", "no"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const line = text.split("\n").find(l => l.startsWith("*"));
                    if (!line) {
                        details.radio = {};
                        return;
                    }
                    const [, signal, channel, frequency, rate, security] = NetworkConnections.splitFields(line);
                    const mhz = parseInt(frequency);
                    details.radio = {
                        signal: `${signal}%`,
                        band: `${mhz >= 5900 ? "6" : mhz >= 4900 ? "5" : "2.4"} GHz · channel ${channel}`,
                        rate: rate,
                        security: security || "Open"
                    };
                }
            }
        }

        Detail { label: "Signal"; value: details.radio.signal ?? "" }
        Detail { label: "Band"; value: details.radio.band ?? "" }
        Detail { label: "Speed"; value: details.radio.rate ?? "" }
        Detail { label: "Security"; value: details.radio.security ?? "" }
        Detail { label: "IP address"; value: details.addresses.join(", ") }
        Detail { label: "Gateway"; value: details.info["IP4.GATEWAY"] ?? "" }
        Detail { label: "DNS"; value: details.dns.join(", ") }
        Detail { label: "IPv6"; value: (details.info["IP6.ADDRESS"] ?? []).join(", ") }
        Detail { label: "MAC address"; value: details.info["GENERAL.HWADDR"] ?? "" }
    }

    // A saved connection: name and status, expanding (remembered for the session) to its
    // auto-connect, IP and DNS settings, and Connect / Disconnect / Forget
    component ConnectionBlock: Block {
        id: block

        property var connection
        property string status
        property bool canConnect: false
        // A VPN: an on/off switch in place of Connect, and no IP settings (the config has them)
        property bool vpn: false

        readonly property string stateKey: `network:${connection.uuid}`
        readonly property bool expanded: PanelState.isOpen("settings", stateKey)

        // Click the title area to expand
        Item {
            width: parent.width
            height: blockHeader.height

            Header {
                id: blockHeader
                title: block.connection.name
                detail: block.status
                accent: block.connection.active

                PanelButton {
                    visible: block.canConnect
                    label: "Connect"
                    onClicked: NetworkConnections.connect(block.connection.uuid)
                }

                Toggle {
                    visible: block.vpn
                    anchors.verticalCenter: parent.verticalCenter
                    checked: block.connection.active
                    onToggled: checked ? NetworkConnections.disconnect(block.connection.uuid) : NetworkConnections.connect(block.connection.uuid)
                }

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    horizontalAlignment: Text.AlignRight
                    text: block.expanded ? "\u{F077}" : "\u{F078}"
                    color: block.expanded ? Theme.accent : Theme.subtext
                    font.pixelSize: Theme.panelFontSize - 3
                }
            }

            MouseArea {
                anchors.fill: parent
                // The Connect button or switch keeps its own clicks
                anchors.rightMargin: block.canConnect ? 120 : block.vpn ? 80 : 0
                cursorShape: Qt.PointingHandCursor
                onClicked: PanelState.toggle("settings", block.stateKey)
            }
        }

        Loader {
            active: block.expanded
            visible: active
            width: parent.width

            sourceComponent: ConnectionEditor {
                connection: block.connection
                vpn: block.vpn
            }
        }
    }

    // A saved connection's settings, read when opened. IP and DNS changes wait for Apply.
    component ConnectionEditor: Column {
        id: editor

        property var connection
        property bool vpn: false
        property var settings: ({})
        property bool loaded: false

        // The form, filled from `settings` once read
        property bool manual: false
        property bool customDns: false
        property bool forgetArmed: false

        readonly property var dnsList: dnsField.text.split(/[\s,]+/).filter(s => s !== "")
        readonly property bool addressValid: /^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$/.test(addressField.text.trim())
        readonly property bool gatewayValid: gatewayField.text.trim() === "" || /^(\d{1,3}\.){3}\d{1,3}$/.test(gatewayField.text.trim())
        readonly property bool dnsValid: dnsList.length > 0 && dnsList.every(s => /^(\d{1,3}\.){3}\d{1,3}$/.test(s) || /^[0-9a-fA-F:]+$/.test(s))
        readonly property bool valid: (!manual || (addressValid && gatewayValid)) && (!customDns || dnsValid)
        readonly property bool changed: loaded && (manual !== (settings["ipv4.method"] === "manual")
            || customDns !== (settings["ipv4.ignore-auto-dns"] === "yes")
            || (manual && (addressField.text.trim() !== (settings["ipv4.addresses"] ?? "") || gatewayField.text.trim() !== (settings["ipv4.gateway"] ?? "")))
            || (customDns && dnsList.join(",") !== (settings["ipv4.dns"] ?? "")))

        function load(): void {
            show.running = true;
        }

        width: parent.width
        spacing: 12

        Component.onCompleted: load()

        Process {
            id: show
            command: ["nmcli", "-t", "-f", "connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.ignore-auto-dns", "connection", "show", editor.connection.uuid]
            stdout: StdioCollector {
                onStreamFinished: {
                    const settings = NetworkConnections.parseShow(text);
                    editor.settings = settings;
                    editor.manual = settings["ipv4.method"] === "manual";
                    editor.customDns = settings["ipv4.ignore-auto-dns"] === "yes";
                    addressField.text = settings["ipv4.addresses"] ?? "";
                    gatewayField.text = settings["ipv4.gateway"] ?? "";
                    dnsField.text = (settings["ipv4.dns"] ?? "").split(",").filter(s => s !== "").join(", ");
                    editor.loaded = true;
                }
            }
        }

        Option {
            label: "Connect automatically"

            Toggle {
                checked: editor.connection.autoconnect
                onToggled: NetworkConnections.setAutoconnect(editor.connection.uuid, !checked)
            }
        }

        // A VPN's addresses come from its config
        Detail {
            visible: editor.vpn && value !== ""
            label: "Address"
            value: editor.settings["ipv4.addresses"] ?? ""
        }

        Detail {
            visible: editor.vpn && value !== ""
            label: "DNS"
            value: (editor.settings["ipv4.dns"] ?? "").split(",").join(", ")
        }

        Option {
            visible: !editor.vpn
            label: "IP address"

            ChoiceButtons {
                choices: [false, true]
                current: editor.manual
                format: manual => manual ? "Manual" : "Automatic (DHCP)"
                onChosen: value => editor.manual = value
            }
        }

        Row {
            visible: !editor.vpn && editor.manual
            spacing: 8

            TextField {
                id: addressField
                width: 220
                placeholder: "Address, e.g. 192.168.1.50/24"
                valid: addressField.text === "" || editor.addressValid
            }

            TextField {
                id: gatewayField
                width: 200
                placeholder: "Gateway, e.g. 192.168.1.1"
                valid: editor.gatewayValid
            }
        }

        Option {
            visible: !editor.vpn
            label: "DNS servers"

            ChoiceButtons {
                choices: [false, true]
                current: editor.customDns
                format: custom => custom ? "Custom" : "Automatic"
                onChosen: value => editor.customDns = value
            }
        }

        TextField {
            id: dnsField
            visible: !editor.vpn && editor.customDns
            width: 428
            placeholder: "Servers, e.g. 1.1.1.1, 9.9.9.9"
            valid: dnsField.text === "" || editor.dnsValid
        }

        Row {
            spacing: 8

            PanelButton {
                visible: editor.changed
                label: editor.connection.active ? "Apply and reconnect" : "Apply"
                highlighted: true
                enabled: editor.valid
                opacity: enabled ? 1 : 0.4
                onClicked: {
                    NetworkConnections.setIpv4(editor.connection.uuid, {
                        manual: editor.manual,
                        address: addressField.text.trim(),
                        gateway: gatewayField.text.trim(),
                        customDns: editor.customDns,
                        dns: editor.dnsList
                    }, editor.connection.active);
                    reload.restart();
                }
            }

            PanelButton {
                visible: editor.connection.active && !editor.vpn
                label: "Disconnect"
                onClicked: NetworkConnections.disconnect(editor.connection.uuid)
            }

            // Twice, within 3 seconds
            PanelButton {
                label: editor.forgetArmed ? "Forget? Click again" : "Forget"
                highlighted: editor.forgetArmed
                onClicked: {
                    if (editor.forgetArmed)
                        NetworkConnections.forget(editor.connection.uuid);
                    editor.forgetArmed = !editor.forgetArmed;
                    disarm.restart();
                }
            }
        }

        Timer {
            id: disarm
            interval: 3000
            onTriggered: editor.forgetArmed = false
        }

        // Re-read the settings once the change has gone through
        Timer {
            id: reload
            interval: 1500
            onTriggered: editor.load()
        }
    }

    // A label on the left and its control on the right, inside an editor
    component Option: Item {
        property string label
        default property alias control: controlArea.data

        width: parent.width
        implicitHeight: Math.max(optionLabel.implicitHeight, controlArea.childrenRect.height)

        PanelText {
            id: optionLabel
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
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

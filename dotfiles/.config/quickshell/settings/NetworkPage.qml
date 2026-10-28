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

    // Saved connections opened here stay open for the session (PanelState); forgotten ones
    // are dropped (once the list has been read)
    readonly property var connectionKeys: NetworkConnections.connections.map(c => `network:${c.uuid}`)
    onConnectionKeysChanged: {
        if (connectionKeys.length > 0)
            PanelState.pruneByPrefix("settings", "network:", connectionKeys);
    }

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

    // Scan for networks while the page is open, also with a Wi-Fi device that turns up later
    // (unblocked, or a USB one plugged in)
    onWifiDeviceChanged: NetworkConnections.setScanning(root, wifiDevice)

    // An error from earlier in the session isn't shown again
    Component.onCompleted: {
        NetworkConnections.error = "";
        NetworkConnections.setScanning(root, wifiDevice);
    }
    Component.onDestruction: NetworkConnections.setScanning(root, null)

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: NetworkConnections.refresh()
    }

    // An action that failed (wrong password, bad address…)
    Banner {
        text: NetworkConnections.error
        closable: true
        onClosed: NetworkConnections.error = ""
    }

    SettingsGroup {
        visible: root.wifiDevice !== null
        title: "Wi-Fi"

        ToggleRow {
            label: "Wi-Fi"
            description: !Networking.wifiHardwareEnabled ? "Switched off by the hardware switch or airplane mode key." : ""
            checked: Networking.wifiEnabled
            onToggled: on => Networking.wifiEnabled = on
        }

        // The network connected to now, and its details
        SettingsBlock {
            visible: root.currentNetwork !== null

            BlockHeader {
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

            SettingsBlock {
                id: availableBlock

                required property var modelData
                readonly property bool secured: modelData.security !== WifiSecurityType.Open
                readonly property bool connecting: modelData.state === ConnectionState.Connecting
                readonly property bool askingPassword: root.passwordNetwork === modelData

                BlockHeader {
                    title: availableBlock.modelData.name
                    detail: availableBlock.connecting ? "Connecting…" : `${availableBlock.secured ? "\u{F023}  Secured" : "Open"} · ${Math.round(availableBlock.modelData.signalStrength * 100)}%`

                    PanelButton {
                        visible: !availableBlock.connecting
                        label: availableBlock.askingPassword ? "Cancel" : "Connect"
                        onClicked: root.connectTo(availableBlock.modelData)
                    }
                }

                WifiPasswordField {
                    visible: availableBlock.askingPassword
                    network: availableBlock.modelData
                    onSubmitted: root.passwordNetwork = null
                    onCancelled: root.passwordNetwork = null
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
                // By the network it's for, which its name needn't be
                readonly property bool inRange: root.inRange.includes(NetworkConnections.ssidOf(modelData))
                status: modelData.active ? "Connected" : inRange ? "In range" : root.ago(modelData.lastUsed)
                canConnect: !modelData.active && inRange
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

        SettingsBlock {
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
                    onAccepted: password.focusInput()
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

        SettingsBlock {
            id: wired

            readonly property bool connected: root.wiredDevice?.connected ?? false

            BlockHeader {
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

        SettingsBlock {
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
    component ConnectionBlock: SettingsBlock {
        id: block

        property var connection
        property string status
        property bool canConnect: false
        // A VPN: an on/off switch in place of Connect, and no IP settings (the config has them)
        property bool vpn: false

        BlockHeader {
            id: blockHeader
            title: block.connection.name
            detail: block.status
            accent: block.connection.active
            expandable: true
            stateKey: `network:${block.connection.uuid}`

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
        }

        Loader {
            active: blockHeader.expanded
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

        // Set up elsewhere as something other than automatic or manual (shared, link-local,
        // disabled): shown, and left as it is
        readonly property string method: settings["ipv4.method"] ?? "auto"
        readonly property bool otherMethod: loaded && method !== "auto" && method !== "manual"

        // IPv4 only: four numbers 0-255, and a prefix 0-32 for the address
        function isIpv4(text: string): bool {
            const parts = text.split(".");
            return parts.length === 4 && parts.every(part => /^\d{1,3}$/.test(part) && Number(part) <= 255);
        }
        readonly property var dnsList: dnsField.text.split(/[\s,]+/).filter(s => s !== "")
        readonly property bool addressValid: {
            const [address, prefix, ...rest] = addressField.text.trim().split("/");
            return rest.length === 0 && isIpv4(address) && /^\d{1,2}$/.test(prefix ?? "") && Number(prefix) <= 32;
        }
        readonly property bool gatewayValid: gatewayField.text.trim() === "" || isIpv4(gatewayField.text.trim())
        readonly property bool dnsValid: dnsList.length > 0 && dnsList.every(s => isIpv4(s))
        readonly property bool valid: (!manual || (addressValid && gatewayValid)) && (!customDns || dnsValid)
        readonly property bool addressChanged: loaded && !otherMethod && (manual !== (method === "manual")
            || (manual && (addressField.text.trim() !== (settings["ipv4.addresses"] ?? "") || gatewayField.text.trim() !== (settings["ipv4.gateway"] ?? ""))))
        readonly property bool dnsChanged: loaded && (customDns !== (settings["ipv4.ignore-auto-dns"] === "yes")
            || (customDns && dnsList.join(",") !== (settings["ipv4.dns"] ?? "")))
        readonly property bool changed: addressChanged || dnsChanged

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

        InlineOption {
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

        Detail {
            visible: !editor.vpn && editor.otherMethod
            label: "IP address"
            value: `${editor.method} (set elsewhere)`
        }

        InlineOption {
            visible: !editor.vpn && !editor.otherMethod
            label: "IP address"

            ChoiceButtons {
                choices: [false, true]
                current: editor.manual
                format: manual => manual ? "Manual" : "Automatic (DHCP)"
                onChosen: value => editor.manual = value
            }
        }

        Row {
            visible: !editor.vpn && !editor.otherMethod && editor.manual
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

        InlineOption {
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
                    // Only what changed: the rest of the connection's settings stay as they are
                    const changes = {};
                    if (editor.addressChanged)
                        changes.address = { manual: editor.manual, address: addressField.text.trim(), gateway: gatewayField.text.trim() };
                    if (editor.dnsChanged)
                        changes.dns = { custom: editor.customDns, servers: editor.dnsList };
                    NetworkConnections.setIpv4(editor.connection.uuid, changes, editor.connection.active);
                    reload.restart();
                }
            }

            PanelButton {
                visible: editor.connection.active && !editor.vpn
                label: "Disconnect"
                onClicked: NetworkConnections.disconnect(editor.connection.uuid)
            }

            ConfirmButton {
                text: "Forget"
                onConfirmed: NetworkConnections.forget(editor.connection.uuid)
            }
        }

        // Re-read the settings once the change has gone through
        Timer {
            id: reload
            interval: 1500
            onTriggered: editor.load()
        }
    }
}

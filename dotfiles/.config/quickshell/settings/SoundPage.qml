import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// Settings › Sound, in place of pavucontrol: every output and input with its volume (up to
// 150% if boosting is allowed), port and a level meter for inputs; apps recording, each
// movable to another input; and the sound cards' profiles. Apps playing are in the audio panel. PipeWire covers the volumes; ports, profiles and
// moving streams go through pactl (AudioCards), re-read every few seconds while open so
// plugging in headphones shows up.
Column {
    id: root

    readonly property var nodes: Pipewire.nodes.values
    readonly property var outputs: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var inputs: nodes.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var inStreams: nodes.filter(n => n.type === PwNodeType.AudioInStream)
    // Not level meters (like this page's own), which record only to measure
    readonly property var recording: inStreams.filter(n => !n.properties["stream.monitor"])

    function nodeName(node: PwNode): string {
        return node ? node.description || node.nickname || node.name : "";
    }

    readonly property real maxVolume: ShellSettings.volumeBoost ? 1.5 : 1

    // What a card profile does, from its name ("output:analog-stereo+input:analog-stereo")
    function describeProfile(name: string): string {
        if (name === "off")
            return "The sound card is switched off";
        if (name === "pro-audio")
            return "Raw channels for music software; not for everyday use";
        const parts = name.split("+");
        const output = parts.find(part => part.startsWith("output:"))?.slice(7) ?? "";
        const hasInput = parts.some(part => part.startsWith("input:"));
        if (output === "")
            return hasInput ? "Microphone only, no sound out" : "";
        const surround = output.includes("surround") ? "surround sound " : "";
        let to = "the speakers or headphones";
        if (output.startsWith("hdmi"))
            to = `${surround === "" ? "" : surround}a screen over HDMI / DisplayPort`;
        else if (output.startsWith("iec958"))
            to = "the digital (S/PDIF) output";
        else if (surround !== "")
            to = "surround speakers";
        else if (output.includes("mono"))
            to = "the speakers or headphones, in mono";
        return hasInput ? `Sound to ${to}, plus the microphone` : `Sound to ${to}; microphone off`;
    }

    // Short tag for a device, e.g. to pick out Bluetooth headphones
    function deviceKind(node: PwNode): string {
        const props = node?.properties ?? {};
        if (props["device.api"] === "bluez5")
            return "Bluetooth";
        if (props["device.bus"] === "usb")
            return "USB";
        const description = (node?.description ?? "").toLowerCase();
        if (description.includes("hdmi") || description.includes("displayport"))
            return "HDMI / DisplayPort";
        return "";
    }

    spacing: 24

    // Needed for the nodes' audio properties to be populated
    PwObjectTracker {
        objects: [...root.outputs, ...root.inputs, ...root.inStreams]
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: AudioCards.refresh()
    }

    SettingsGroup {
        title: "Output devices"

        Repeater {
            model: root.outputs

            DeviceBlock {
                required property PwNode modelData
                device: modelData
                isDefault: modelData === Pipewire.defaultAudioSink
                onMakeDefault: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        // Outputs behind another card profile (e.g. HDMI while the card is on analog)
        Repeater {
            model: AudioCards.hiddenOutputs

            SettingRow {
                required property var modelData
                label: modelData.label
                description: modelData.label.includes(modelData.kind) ? "Switches the sound card over to it." : `${modelData.kind}. Switches the sound card over to it.`

                PanelButton {
                    label: "Switch to"
                    onClicked: AudioCards.switchTo(modelData)
                }
            }
        }
    }

    SettingsGroup {
        title: "Input devices"

        Repeater {
            model: root.inputs

            DeviceBlock {
                required property PwNode modelData
                device: modelData
                isDefault: modelData === Pipewire.defaultAudioSource
                showMeter: true
                onMakeDefault: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        SettingRow {
            visible: root.inputs.length === 0
            label: "No inputs"
        }
    }

    SettingsGroup {
        visible: root.recording.length > 0
        title: "Recording"

        Repeater {
            model: root.recording

            StreamBlock {
                required property PwNode modelData
                stream: modelData
                devices: root.inputs
            }
        }
    }

    SettingsGroup {
        visible: AudioCards.cards.length > 0
        title: "Sound cards"

        Repeater {
            model: AudioCards.cards

            Block {
                id: cardBlock

                required property var modelData
                readonly property var active: modelData.profiles.find(p => p.name === modelData.activeProfile)

                Header {
                    title: cardBlock.modelData.description
                    detail: "Profile"

                    Picker {
                        label: cardBlock.active?.description ?? cardBlock.modelData.activeProfile
                        open: profileList.expanded
                        onClicked: profileList.toggle()
                    }
                }

                // Profiles that can be used now, best first
                DropdownList {
                    id: profileList
                    width: parent.width
                    items: cardBlock.modelData.profiles
                        .filter(profile => profile.available)
                        .map(profile => ({
                                    label: profile.description,
                                    sublabel: root.describeProfile(profile.name),
                                    selected: profile.name === cardBlock.modelData.activeProfile,
                                    profile: profile.name
                                }))
                    onChosen: item => AudioCards.setProfile(cardBlock.modelData.name, item.profile)
                }
            }
        }
    }

    SettingsGroup {
        title: "Options"

        SettingRow {
            changed: !ShellSettings.isDefault("volumeBoost")
            onReset: ShellSettings.reset("volumeBoost")
            label: "Allow volume above 100%"
            description: "Boosts quiet sound up to 150%, in software. Loud sounds may distort."

            Toggle {
                checked: ShellSettings.volumeBoost
                onToggled: ShellSettings.volumeBoost = !checked
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

    // Title and dim detail on the left, anything (a button, a picker) on the right
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

        Item {
            id: trailingArea
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    // A button naming the current choice, with a chevron, that opens a DropdownList below
    component Picker: PanelButton {
        property bool open: false

        icon: open ? "\u{F077}" : "\u{F078}"
        highlighted: open
    }

    // Mute, a slider up to 100% (150% with boosting allowed, marked at 100%), and the percentage
    component VolumeControl: Row {
        id: volumeControl

        property PwNode node
        readonly property bool muted: node?.audio?.muted ?? false
        readonly property real volume: node?.audio?.volume ?? 0
        property string icon: "\u{F028}"
        property string mutedIcon: "\u{EEE8}"

        width: parent.width
        spacing: 10

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            icon: volumeControl.muted ? volumeControl.mutedIcon : volumeControl.icon
            highlighted: volumeControl.muted
            onClicked: {
                if (volumeControl.node?.audio)
                    volumeControl.node.audio.muted = !volumeControl.muted;
            }
        }

        Slider {
            id: slider
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 36 - 46 - 20
            to: root.maxVolume
            value: volumeControl.volume
            onMoved: value => {
                if (volumeControl.node?.audio)
                    volumeControl.node.audio.volume = value;
            }

            // 100%: above it is boosted, and may distort
            Rectangle {
                visible: root.maxVolume > 1
                x: slider.width / root.maxVolume - 1
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 12
                radius: 1
                color: Theme.subtext
            }
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(volumeControl.volume * 100)}%`
            color: volumeControl.volume > 1.005 ? Theme.warning : Theme.subtext
        }
    }

    // An output or input: name, default or "Make default", volume, port and (inputs) level
    component DeviceBlock: Block {
        id: deviceBlock

        property PwNode device
        property bool isDefault: false
        property bool showMeter: false
        signal makeDefault

        readonly property var portInfo: AudioCards.ports[device?.name ?? ""] ?? null

        Header {
            title: root.nodeName(deviceBlock.device)
            detail: root.deviceKind(deviceBlock.device)
            accent: deviceBlock.isDefault

            PanelText {
                visible: deviceBlock.isDefault
                text: "\u{F00C}  Default"
                color: Theme.accent
            }

            PanelButton {
                visible: !deviceBlock.isDefault
                label: "Make default"
                onClicked: deviceBlock.makeDefault()
            }
        }

        VolumeControl {
            node: deviceBlock.device
            icon: deviceBlock.device?.isSink ? "\u{F028}" : "\u{F130}"
            mutedIcon: deviceBlock.device?.isSink ? "\u{EEE8}" : "\u{F131}"
        }

        // Only when there's a choice; unplugged ones are greyed out
        Row {
            visible: (deviceBlock.portInfo?.ports.length ?? 0) > 1
            spacing: 12

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Port"
                dim: true
            }

            ChoiceButtons {
                readonly property var ports: deviceBlock.portInfo?.ports ?? []

                choices: ports.map(port => port.name)
                current: deviceBlock.portInfo?.active ?? ""
                format: name => {
                    const port = ports.find(p => p.name === name);
                    return port.available ? port.description : `${port.description} (unplugged)`;
                }
                isEnabled: name => ports.find(p => p.name === name)?.available ?? false
                onChosen: name => AudioCards.setPort(deviceBlock.device, name)
            }
        }

        // Input level, to check the mic picks up
        Rectangle {
            visible: deviceBlock.showMeter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.surface

            Rectangle {
                width: parent.width * Math.min(1, meter.peak)
                height: parent.height
                radius: parent.radius
                color: Theme.charging

                Behavior on width {
                    NumberAnimation { duration: 80 }
                }
            }

            PwNodePeakMonitor {
                id: meter
                node: deviceBlock.device
                enabled: deviceBlock.showMeter
            }
        }
    }

    // An app's recording stream: the app, the input it records from, and its volume
    component StreamBlock: Block {
        id: streamBlock

        property PwNode stream
        property var devices: []

        readonly property string app: stream?.properties["application.name"] ?? stream?.name ?? ""
        // What it's playing, if known (Firefox renames its streams "AudioStream"; see StreamTitles)
        readonly property string title: stream ? StreamTitles.title(stream) : ""
        // The input it's linked to (from all links: a PwNodeLinkTracker on the stream reported
        // none)
        readonly property PwNode device: {
            for (const group of Pipewire.linkGroups.values) {
                const other = group.source === stream ? group.target : group.target === stream ? group.source : null;
                if (other && devices.includes(other))
                    return other;
            }
            return null;
        }

        Header {
            title: streamBlock.app
            detail: streamBlock.title !== streamBlock.app ? streamBlock.title : ""

            Picker {
                label: streamBlock.device ? root.nodeName(streamBlock.device) : "Not connected"
                open: deviceList.expanded
                onClicked: deviceList.toggle()
            }
        }

        DropdownList {
            id: deviceList
            width: parent.width
            items: streamBlock.devices.map(device => ({
                        label: root.nodeName(device),
                        sublabel: root.deviceKind(device),
                        selected: device === streamBlock.device,
                        device: device
                    }))
            onChosen: item => AudioCards.moveStream(streamBlock.stream, item.device)
        }

        VolumeControl {
            node: streamBlock.stream
            icon: streamBlock.stream?.type === PwNodeType.AudioInStream ? "\u{F130}" : "\u{F028}"
            mutedIcon: streamBlock.stream?.type === PwNodeType.AudioInStream ? "\u{F131}" : "\u{EEE8}"
        }

    }
}

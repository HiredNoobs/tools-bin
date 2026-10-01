import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// Opened from the speaker or mic icon: volumes, device choice and per-app volume
Column {
    id: root

    signal closeRequested

    readonly property var nodes: Pipewire.nodes.values
    readonly property var outputs: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var inputs: nodes.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var apps: nodes.filter(n => n.type === PwNodeType.AudioOutStream)

    function nodeName(node: PwNode): string {
        return node.description || node.nickname || node.name;
    }

    // Short tag shown under a device name, e.g. to pick out Bluetooth headphones
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

    width: 340
    spacing: 10

    Component.onCompleted: AudioCards.refresh()

    // Needed for the nodes' audio properties to be populated
    PwObjectTracker {
        objects: [...root.outputs, ...root.inputs, ...root.apps]
    }

    PanelSection {
        text: "Output"
    }

    VolumeRow {
        node: Pipewire.defaultAudioSink
        icon: "\u{F028}"
        mutedIcon: "\u{EEE8}"
        devices: root.outputs
        hiddenDevices: AudioCards.hiddenOutputs
        onDeviceChosen: device => Pipewire.preferredDefaultAudioSink = device
    }

    PanelSection {
        text: "Input"
    }

    VolumeRow {
        node: Pipewire.defaultAudioSource
        icon: "\u{F130}"
        mutedIcon: "\u{F131}"
        devices: root.inputs
        onDeviceChosen: device => Pipewire.preferredDefaultAudioSource = device
    }

    PanelSection {
        visible: root.apps.length > 0
        text: "Apps"
    }

    Repeater {
        model: root.apps

        VolumeRow {
            required property PwNode modelData
            node: modelData
            icon: "\u{F028}"
            mutedIcon: "\u{EEE8}"
            label: modelData.properties["application.name"] ?? modelData.name
        }
    }

    Item {
        width: parent.width
        height: 4
    }

    PanelButton {
        width: parent.width
        icon: "\u{F013}"
        label: "Open pavucontrol"
        onClicked: {
            Exec.floating("pavucontrol", false);
            root.closeRequested();
        }
    }

    // Devices to switch between, sliding open under a volume row; the current one is ticked
    component DeviceList: Item {
        id: deviceList

        property var devices: []
        // Outputs behind another card profile (AudioCards); choosing one switches the profile
        property var hiddenDevices: []
        property PwNode current
        property bool expanded: false
        signal chosen(PwNode device)
        signal hiddenChosen(var device)

        width: root.width
        height: expanded ? rows.implicitHeight : 0
        clip: true

        // The panel grows with it
        Behavior on height {
            NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
        }

        Column {
            id: rows
            width: parent.width
            topPadding: 4
            spacing: 2

            Repeater {
                model: deviceList.devices

                ListRow {
                    id: deviceRow

                    required property PwNode modelData

                    width: rows.width
                    label: root.nodeName(modelData)
                    sublabel: root.deviceKind(modelData)
                    selected: modelData === deviceList.current
                    onClicked: deviceList.chosen(modelData)

                    PanelText {
                        visible: deviceRow.selected
                        text: "\u{F00C}"
                        color: Theme.accent
                    }
                }
            }

            Repeater {
                model: deviceList.hiddenDevices

                ListRow {
                    required property var modelData

                    width: rows.width
                    label: modelData.label
                    sublabel: modelData.kind
                    onClicked: deviceList.hiddenChosen(modelData)
                }
            }
        }
    }

    // Mute button, slider, percentage and (with `devices`) a drop-down of devices to switch to,
    // with an optional name above
    component VolumeRow: Column {
        id: volumeRow

        property PwNode node
        property string icon
        property string mutedIcon
        property string label: ""
        property var devices: null
        property var hiddenDevices: []
        signal deviceChosen(PwNode device)

        readonly property bool hasDevices: devices !== null
        readonly property int dropdownWidth: hasDevices ? 36 + 10 : 0

        readonly property bool muted: node?.audio?.muted ?? false
        readonly property real volume: node?.audio?.volume ?? 0

        width: root.width
        spacing: 4

        PanelText {
            visible: volumeRow.label !== ""
            width: parent.width
            text: volumeRow.label
            elide: Text.ElideRight
            dim: true
        }

        Row {
            width: parent.width
            spacing: 10

            PanelButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                icon: volumeRow.muted ? volumeRow.mutedIcon : volumeRow.icon
                highlighted: volumeRow.muted
                onClicked: {
                    if (volumeRow.node?.audio)
                        volumeRow.node.audio.muted = !volumeRow.muted;
                }
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - 38 - 20 - volumeRow.dropdownWidth
                value: volumeRow.volume
                onMoved: value => {
                    if (volumeRow.node?.audio)
                        volumeRow.node.audio.volume = value;
                }
            }

            // Wide enough for "100%"
            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                text: `${Math.round(volumeRow.volume * 100)}%`
                dim: true
            }

            PanelButton {
                visible: volumeRow.hasDevices
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                icon: devicePicker.expanded ? "\u{F077}" : "\u{F078}"
                highlighted: devicePicker.expanded
                onClicked: devicePicker.expanded = !devicePicker.expanded
            }
        }

        DeviceList {
            id: devicePicker
            visible: volumeRow.hasDevices
            devices: volumeRow.devices ?? []
            hiddenDevices: volumeRow.hiddenDevices
            current: volumeRow.node
            onChosen: device => {
                volumeRow.deviceChosen(device);
                expanded = false;
            }
            onHiddenChosen: device => {
                AudioCards.switchTo(device);
                expanded = false;
            }
        }
    }
}

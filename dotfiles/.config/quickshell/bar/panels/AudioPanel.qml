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

    width: 340
    spacing: 10

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
    }

    Repeater {
        model: root.outputs.length > 1 ? root.outputs : []

        ListRow {
            id: deviceRow
            required property PwNode modelData
            width: root.width
            label: root.nodeName(modelData)
            selected: modelData === Pipewire.defaultAudioSink
            onClicked: Pipewire.preferredDefaultAudioSink = modelData

            PanelText {
                visible: deviceRow.selected
                text: "\u{F00C}"
                color: Theme.accent
            }
        }
    }

    PanelSection {
        text: "Input"
    }

    VolumeRow {
        node: Pipewire.defaultAudioSource
        icon: "\u{F130}"
        mutedIcon: "\u{F131}"
    }

    Repeater {
        model: root.inputs.length > 1 ? root.inputs : []

        ListRow {
            id: deviceRow
            required property PwNode modelData
            width: root.width
            label: root.nodeName(modelData)
            selected: modelData === Pipewire.defaultAudioSource
            onClicked: Pipewire.preferredDefaultAudioSource = modelData

            PanelText {
                visible: deviceRow.selected
                text: "\u{F00C}"
                color: Theme.accent
            }
        }
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

    // Mute button, slider and percentage for one node, with an optional name above
    component VolumeRow: Column {
        id: volumeRow

        property PwNode node
        property string icon
        property string mutedIcon
        property string label: ""

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
                width: parent.width - 36 - 50 - 20
                value: volumeRow.volume
                onMoved: value => {
                    if (volumeRow.node?.audio)
                        volumeRow.node.audio.volume = value;
                }
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(volumeRow.volume * 100)}%`
                dim: true
            }
        }
    }
}

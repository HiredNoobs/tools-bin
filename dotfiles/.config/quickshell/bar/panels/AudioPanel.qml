import QtQuick
import Quickshell
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

    // App streams grouped by app, in order of appearance: [{ name, streams }]. Each Firefox tab
    // (and the like) is its own stream
    readonly property var appGroups: {
        const groups = [];
        for (const stream of apps) {
            const name = AudioNodes.appName(stream);
            const group = groups.find(g => g.name === name);
            if (group)
                group.streams.push(stream);
            else
                groups.push({ name: name, streams: [stream] });
        }
        return groups;
    }
    // What a stream is playing, e.g. a browser tab's title
    function streamTitle(stream: PwNode): string {
        return StreamTitles.title(stream);
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
        devicesKey: "output"
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
        devicesKey: "input"
        onDeviceChosen: device => Pipewire.preferredDefaultAudioSource = device
    }

    PanelSection {
        visible: root.apps.length > 0
        text: "Apps"
    }

    // By app name, so an app's row (and a slider being dragged) stays when streams come and
    // go; the groups themselves are made again each time
    Repeater {
        model: ScriptModel {
            values: root.appGroups.map(group => group.name)
        }

        AppVolume {
            required property string modelData
            name: modelData
            streams: root.appGroups.find(group => group.name === modelData)?.streams ?? []
        }
    }

    Item {
        width: parent.width
        height: 4
    }

    // The settings window's Sound section: every device, port and card profile
    PanelButton {
        width: parent.width
        icon: "\u{F013}"
        label: "Sound settings"
        onClicked: {
            Exec.run("qs ipc call settings open sound");
            root.closeRequested();
        }
    }

    // An app's volume. With one stream, a row for it (named after what it plays, if anything);
    // with more, a row for the whole app that can expand to show each stream. PipeWire has no
    // per-app volume, so the app's row shows its loudest stream and scales them all together,
    // keeping their balance, and mutes or unmutes them all.
    component AppVolume: Column {
        id: appVolume

        property string name
        property var streams: []

        readonly property bool grouped: streams.length > 1
        readonly property bool expanded: PanelState.isOpen("audio", name)
        readonly property real volume: Math.max(0, ...streams.map(s => s.audio?.volume ?? 0))
        readonly property bool muted: streams.every(s => s.audio?.muted ?? false)
        // Each stream's share of the loudest, so dragging the app to 0 and back keeps them
        property var balance: ({})

        function setVolume(value: real): void {
            if (volume > 0) {
                const shares = {};
                for (const stream of streams)
                    shares[stream.id] = (stream.audio?.volume ?? 0) / volume;
                balance = shares;
            }
            for (const stream of streams) {
                if (stream.audio)
                    stream.audio.volume = value * (balance[stream.id] ?? 1);
            }
        }

        function setMuted(muted: bool): void {
            for (const stream of streams) {
                if (stream.audio)
                    stream.audio.muted = muted;
            }
        }

        width: root.width
        spacing: 8

        VolumeRow {
            visible: !appVolume.grouped
            node: appVolume.streams[0] ?? null
            icon: "\u{F028}"
            mutedIcon: "\u{EEE8}"
            label: appVolume.name
            sublabel: appVolume.streams[0] ? root.streamTitle(appVolume.streams[0]) : ""
        }

        VolumeRow {
            visible: appVolume.grouped
            icon: "\u{F028}"
            mutedIcon: "\u{EEE8}"
            label: appVolume.name
            sublabel: `${appVolume.streams.length} streams`
            volume: appVolume.volume
            muted: appVolume.muted
            expandable: true
            expanded: appVolume.expanded
            onVolumeSet: value => appVolume.setVolume(value)
            onMuteToggled: appVolume.setMuted(!appVolume.muted)
            onExpandToggled: PanelState.toggle("audio", appVolume.name)
        }

        // The streams, indented under the app
        Column {
            visible: appVolume.grouped && appVolume.expanded
            x: 16
            width: parent.width - x
            spacing: 8

            Repeater {
                model: ScriptModel {
                    values: appVolume.grouped ? appVolume.streams : []
                }

                VolumeRow {
                    required property PwNode modelData
                    required property int index
                    width: parent.width
                    node: modelData
                    icon: "\u{F028}"
                    mutedIcon: "\u{EEE8}"
                    label: root.streamTitle(modelData) || `Stream ${index + 1}`
                }
            }
        }
    }

    // Mute button, slider, percentage and (with `devices`) a drop-down of devices to switch to,
    // with an optional name (and dim detail) above. Without a `node`, it shows `volume` and
    // `muted` as given and emits volumeSet / muteToggled for the owner to apply; with
    // `expandable`, its chevron emits expandToggled instead of opening a device list.
    component VolumeRow: Column {
        id: volumeRow

        property PwNode node: null
        property string icon
        property string mutedIcon
        property string label: ""
        property string sublabel: ""
        property var devices: null
        property var hiddenDevices: []
        // Remembers whether the device list is open (see PanelState's "devices")
        property string devicesKey: ""
        property bool expandable: false
        property bool expanded: false
        signal deviceChosen(PwNode device)
        signal volumeSet(real value)
        signal muteToggled
        signal expandToggled

        readonly property bool hasDevices: devices !== null
        // Drop-down entries: PipeWire devices, then outputs behind another card profile
        readonly property var deviceItems: [
            ...(devices ?? []).map(device => ({
                label: AudioNodes.nodeName(device),
                sublabel: AudioNodes.deviceKind(device),
                selected: device === node,
                device: device
            })),
            ...hiddenDevices.map(hidden => ({
                label: hidden.label,
                sublabel: hidden.kind,
                hidden: hidden
            }))
        ]
        readonly property int dropdownWidth: hasDevices || expandable ? 36 + 10 : 0

        property bool muted: node?.audio?.muted ?? false
        property real volume: node?.audio?.volume ?? 0

        width: root.width
        spacing: 4

        Row {
            visible: volumeRow.label !== ""
            width: parent.width
            spacing: 8

            PanelText {
                id: labelText
                width: Math.min(implicitWidth, parent.width)
                text: volumeRow.label
                elide: Text.ElideRight
                dim: true
            }

            PanelText {
                visible: volumeRow.sublabel !== ""
                width: parent.width - labelText.width - parent.spacing
                text: `·  ${volumeRow.sublabel}`
                elide: Text.ElideRight
                dim: true
                opacity: 0.7
            }
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
                    else if (!volumeRow.node)
                        volumeRow.muteToggled();
                }
            }

            Slider {
                id: slider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - 38 - 20 - volumeRow.dropdownWidth
                to: AudioNodes.maxVolume
                value: volumeRow.volume
                onMoved: value => {
                    if (volumeRow.node?.audio)
                        volumeRow.node.audio.volume = value;
                    else if (!volumeRow.node)
                        volumeRow.volumeSet(value);
                }

                // 100%, when the slider goes beyond it: above is boosted and may distort
                Rectangle {
                    visible: AudioNodes.maxVolume > 1
                    x: slider.width / AudioNodes.maxVolume - 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 12
                    radius: 1
                    color: Theme.subtext
                }
            }

            // Wide enough for "100%"; amber when boosted
            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                text: `${Math.round(volumeRow.volume * 100)}%`
                color: volumeRow.volume > 1.005 ? Theme.warning : Theme.subtext
            }

            PickerButton {
                visible: volumeRow.hasDevices || volumeRow.expandable
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                open: volumeRow.expandable ? volumeRow.expanded : devicePicker.expanded
                onClicked: {
                    if (volumeRow.expandable)
                        volumeRow.expandToggled();
                    else
                        devicePicker.toggle();
                }
            }
        }

        DropdownList {
            id: devicePicker
            stateSection: volumeRow.devicesKey !== "" ? "devices" : ""
            stateKey: volumeRow.devicesKey
            visible: volumeRow.hasDevices
            width: parent.width
            items: volumeRow.deviceItems
            onChosen: item => item.device ? volumeRow.deviceChosen(item.device) : AudioCards.switchTo(item.hidden)
        }
    }
}

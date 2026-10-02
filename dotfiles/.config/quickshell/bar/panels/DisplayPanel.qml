import QtQuick
import qs
import qs.components
import qs.services

// Opened from the display icon: brightness (laptop only), nightlight and monitors
Column {
    id: root

    signal closeRequested

    // Which monitors' settings are open, by name, in PanelState: outside the rows because every
    // change re-reads the monitor list, which rebuilds them; forgotten once a monitor is gone
    readonly property var monitorNames: Monitors.monitors.map(monitor => monitor.name)
    onMonitorNamesChanged: {
        PanelState.prune("monitors", monitorNames);
        PanelState.prune("modes", monitorNames);
    }

    function toggleExpanded(name: string): void {
        PanelState.toggle("monitors", name);
    }

    // "1920x1080@59.98" -> "1920×1080 · 59.98 Hz"
    function formatMode(mode: string): string {
        const [size, rate] = mode.split("@");
        return `${size.replace("x", "×")} · ${parseFloat(rate)} Hz`;
    }

    width: 340
    spacing: 10

    Component.onCompleted: {
        Nightlight.refresh();
        Monitors.refresh();
    }

    PanelSection {
        visible: Brightness.available
        text: "Brightness"
    }

    Row {
        visible: Brightness.available
        width: parent.width
        spacing: 10

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F00DE}"
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 90
            value: Brightness.fraction
            from: Brightness.minFraction
            to: 1
            onMoved: value => Brightness.set(value)
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(Brightness.fraction * 100)}%`
            dim: true
        }
    }

    PanelSection {
        text: "Nightlight"
    }

    ListRow {
        width: parent.width
        icon: "\u{F0594}"
        label: "Nightlight"
        sublabel: Nightlight.enabled ? `${Nightlight.temperature} K` : "Off"
        selected: Nightlight.enabled
        onClicked: Nightlight.setEnabled(!Nightlight.enabled)

        Toggle {
            checked: Nightlight.enabled
            onToggled: Nightlight.setEnabled(!Nightlight.enabled)
        }
    }

    PanelSection {
        text: "Monitors"
    }

    Repeater {
        model: Monitors.monitors

        MonitorRow {
            required property var modelData
            monitor: modelData
        }
    }

    PanelText {
        visible: Monitors.lastError !== ""
        width: parent.width
        text: Monitors.lastError
        color: Theme.accent
        wrapMode: Text.Wrap
    }

    // Changes above are live; saving keeps them across Hyprland restarts
    Row {
        spacing: 8

        PanelButton {
            icon: "\u{F0193}"
            label: "Save layout"
            onClicked: Monitors.save()
        }

        PanelButton {
            visible: Monitors.hasSaved
            label: "Use defaults"
            onClicked: Monitors.resetSaved()
        }
    }

    // One monitor: on/off switch, and settings that slide open
    component MonitorRow: Column {
        id: monitorRow

        property var monitor
        readonly property bool expanded: PanelState.isOpen("monitors", monitor.name)
        readonly property bool active: !monitor.disabled
        readonly property var other: Monitors.otherOf(monitor.name)
        readonly property string relation: Monitors.relationOf(monitor.name)

        width: root.width
        spacing: 2

        ListRow {
            width: parent.width
            icon: "\u{F0379}"
            label: monitorRow.monitor.model ? `${monitorRow.monitor.name} · ${monitorRow.monitor.model}` : monitorRow.monitor.name
            sublabel: {
                if (!monitorRow.active)
                    return "Off";
                if (monitorRow.monitor.mirrorOf !== "")
                    return `Mirroring ${monitorRow.monitor.mirrorOf}`;
                return `${root.formatMode(monitorRow.monitor.mode)} · ${monitorRow.monitor.scale}×`;
            }
            selected: monitorRow.expanded
            onClicked: root.toggleExpanded(monitorRow.monitor.name)

            Row {
                spacing: 10

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: monitorRow.active
                    onToggled: Monitors.setEnabled(monitorRow.monitor.name, !monitorRow.active)
                }

                // Always shown, so the toggle doesn't move when the monitor is turned off
                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: monitorRow.expanded ? "\u{F077}" : "\u{F078}"
                    color: monitorRow.expanded ? Theme.accent : Theme.subtext
                    font.pixelSize: Theme.panelFontSize - 3
                }
            }
        }

        // Settings, sliding open; the panel grows with them. Read-only while the monitor is off
        Item {
            width: parent.width
            height: monitorRow.expanded ? details.implicitHeight : 0
            clip: true

            Behavior on height {
                NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
            }

            Column {
                id: details
                x: 16
                width: parent.width - 16
                topPadding: 4
                bottomPadding: 6
                spacing: 6
                enabled: monitorRow.active
                opacity: monitorRow.active ? 1 : 0.45

                PanelText {
                    visible: !monitorRow.active
                    text: "Turn the monitor on to change these"
                    dim: true
                    font.pixelSize: Theme.panelFontSize - 1
                }

                ListRow {
                    width: parent.width
                    label: "Resolution"
                    sublabel: root.formatMode(monitorRow.monitor.mode)
                    selected: modeList.expanded
                    onClicked: modeList.toggle()

                    PanelText {
                        text: modeList.expanded ? "\u{F077}" : "\u{F078}"
                        color: modeList.expanded ? Theme.accent : Theme.subtext
                        font.pixelSize: Theme.panelFontSize - 3
                    }
                }

                DropdownList {
                    id: modeList
                    width: parent.width
                    stateSection: "modes"
                    stateKey: monitorRow.monitor.name
                    items: monitorRow.monitor.modes.map(mode => ({
                        label: root.formatMode(mode),
                        selected: mode === monitorRow.monitor.mode,
                        mode: mode
                    }))
                    onChosen: item => Monitors.setMode(monitorRow.monitor.name, item.mode)
                }

                OptionRow {
                    title: "Scale"

                    Repeater {
                        model: Monitors.scales

                        PanelButton {
                            required property real modelData
                            label: `${modelData}×`
                            highlighted: Math.abs(monitorRow.monitor.scale - modelData) < 0.01
                            onClicked: Monitors.setScale(monitorRow.monitor.name, modelData)
                        }
                    }
                }

                // Relative to the other active monitor
                OptionRow {
                    visible: monitorRow.other !== null
                    title: "Position"
                    caption: monitorRow.other ? `relative to ${monitorRow.other.name}` : ""

                    Repeater {
                        model: [
                            { relation: "left", label: "Left" },
                            { relation: "right", label: "Right" },
                            { relation: "above", label: "Above" },
                            { relation: "below", label: "Below" },
                            { relation: "mirror", label: "Mirror" }
                        ]

                        PanelButton {
                            required property var modelData
                            label: modelData.label
                            highlighted: monitorRow.relation === modelData.relation
                            onClicked: Monitors.arrange(monitorRow.monitor.name, modelData.relation)
                        }
                    }
                }
            }
        }
    }

    // A small heading with a wrapping row of option buttons under it
    component OptionRow: Column {
        property string title
        property string caption: ""
        default property alias options: optionFlow.data

        width: parent.width
        spacing: 4

        PanelText {
            text: parent.caption !== "" ? `${parent.title}  ·  ${parent.caption}` : parent.title
            dim: true
            font.pixelSize: Theme.panelFontSize - 1
        }

        Flow {
            id: optionFlow
            width: parent.width
            spacing: 6
        }
    }
}

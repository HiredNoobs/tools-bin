import QtQuick
import qs
import qs.components
import qs.services

// Opened from the display icon: brightness (the laptop's, and external monitors' over DDC),
// nightlight and monitors
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
        ExternalBrightness.detect();
    }

    PanelSection {
        visible: Brightness.available || ExternalBrightness.available
        text: "Brightness"
    }

    // Named like the external monitors' sliders when there are any
    PanelText {
        visible: Brightness.available && ExternalBrightness.available
        text: "Built-in"
        dim: true
        font.pixelSize: Theme.panelFontSize - 2
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

    // Each external monitor: its name, then its slider
    Repeater {
        model: ExternalBrightness.displays

        Column {
            id: external

            required property var modelData

            width: root.width
            spacing: 4

            PanelText {
                text: external.modelData.name
                dim: true
                font.pixelSize: Theme.panelFontSize - 2
            }

            Row {
                width: parent.width
                spacing: 10

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F0379}"
                }

                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                    value: ExternalBrightness.level(external.modelData.name)
                    from: 0
                    to: 1
                    onMoved: value => ExternalBrightness.set(external.modelData.name, value)
                }

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: `${Math.round(ExternalBrightness.level(external.modelData.name) * 100)}%`
                    dim: true
                }
            }
        }
    }

    PanelSection {
        text: "Nightlight"
    }

    // Warmth, right is warmer (Nightlight.warmth, as in Settings › Displays); moving it
    // switches nightlight on. The on/off switch is a quick toggle when the control centre is on.
    Row {
        width: parent.width
        spacing: 10

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F0594}"
            color: Nightlight.enabled ? Theme.accent : Theme.text
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 100 - (nightlightToggle.visible ? nightlightToggle.width + parent.spacing : 0)
            value: Nightlight.warmth
            onMoved: value => {
                Nightlight.setWarmth(value);
                if (!Nightlight.enabled)
                    Nightlight.setEnabled(true);
            }
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            horizontalAlignment: Text.AlignRight
            text: Nightlight.enabled ? `${Nightlight.temperature} K` : "Off"
            dim: true
        }

        Toggle {
            id: nightlightToggle
            visible: !Theme.controlCentre
            anchors.verticalCenter: parent.verticalCenter
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

    Banner {
        text: Monitors.lastError
        closable: true
        onClosed: Monitors.lastError = ""
    }

    // Changes above are live; saving keeps them across Hyprland restarts
    Row {
        spacing: 8

        PanelButton {
            icon: "\u{F0193}"
            label: "Save layout"
            // Not while a change waits to be kept: it may be about to be undone
            enabled: !Monitors.confirming
            opacity: enabled ? 1 : 0.4
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
                ExpandChevron {
                    anchors.verticalCenter: parent.verticalCenter
                    expanded: monitorRow.expanded
                }
            }
        }

        // Settings, sliding open. Read-only while the monitor is off
        Collapsible {
            expanded: monitorRow.expanded

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

                    ExpandChevron {
                        expanded: modeList.expanded
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

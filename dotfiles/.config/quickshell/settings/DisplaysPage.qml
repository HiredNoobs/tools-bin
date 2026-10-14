import QtQuick
import qs
import qs.components
import qs.services

// Settings › Displays: the screens' layout (drag them into place; they snap edge to edge),
// each screen's resolution, refresh rate, scale, rotation, adaptive sync and mirroring, saving
// the layout for login, the laptop's brightness and nightlight with an optional schedule.
// Changes that could blank a screen ask to be kept (bar/DisplayConfirm, on every screen) and
// undo themselves after 15 seconds (Monitors.guard).
Column {
    id: root

    readonly property var monitors: Monitors.monitors

    function displayName(monitor: var): string {
        return monitor.name.startsWith("eDP") ? "Built-in display" : monitor.model || monitor.name;
    }

    // "1920x1080@59.98" -> [width, height, rate]
    function splitMode(mode: string): var {
        const [size, rate] = mode.split("@");
        const [width, height] = size.split("x").map(Number);
        return [width, height, Number(rate)];
    }

    function formatRate(rate: real): string {
        return `${Math.round(rate * 100) / 100} Hz`;
    }

    // Where a dragged screen lands: touching the nearest side of another screen, lined up with
    // its top or bottom when close, keeping some overlap along that side
    function snap(monitor: var, x: real, y: real): var {
        const others = Monitors.enabledMonitors.filter(m => m.name !== monitor.name && m.mirrorOf === "");
        const w = monitor.logicalWidth;
        const h = monitor.logicalHeight;
        const near = 60;
        let best = null;
        for (const o of others) {
            const alignY = v => {
                const clamped = Math.max(o.y - h + near, Math.min(o.y + o.logicalHeight - near, v));
                if (Math.abs(clamped - o.y) < near)
                    return o.y;
                if (Math.abs(clamped + h - (o.y + o.logicalHeight)) < near)
                    return o.y + o.logicalHeight - h;
                return clamped;
            };
            const alignX = v => {
                const clamped = Math.max(o.x - w + near, Math.min(o.x + o.logicalWidth - near, v));
                if (Math.abs(clamped - o.x) < near)
                    return o.x;
                if (Math.abs(clamped + w - (o.x + o.logicalWidth)) < near)
                    return o.x + o.logicalWidth - w;
                return clamped;
            };
            const candidates = [
                [o.x + o.logicalWidth, alignY(y)],
                [o.x - w, alignY(y)],
                [alignX(x), o.y + o.logicalHeight],
                [alignX(x), o.y - h]
            ];
            for (const [cx, cy] of candidates) {
                const distance = Math.hypot(cx - x, cy - y);
                if (!best || distance < best.distance)
                    best = { x: cx, y: cy, distance: distance };
            }
        }
        return best ? [Math.round(best.x), Math.round(best.y)] : [Math.round(x), Math.round(y)];
    }

    spacing: 24

    PanelText {
        visible: Monitors.lastError !== ""
        width: parent.width
        text: `\u{F0026}  ${Monitors.lastError}`
        wrapMode: Text.WordWrap
        color: Theme.critical
    }

    // The layout: screens drawn to scale, dragged into place
    SettingsGroup {
        visible: Monitors.enabledMonitors.length > 1
        title: "Layout"

        Item {
            id: canvas

            // Mirrored screens sit on another, so aren't drawn
            readonly property var shown: Monitors.enabledMonitors.filter(m => m.mirrorOf === "")
            readonly property real minX: Math.min(...shown.map(m => m.x))
            readonly property real minY: Math.min(...shown.map(m => m.y))
            readonly property real maxX: Math.max(...shown.map(m => m.x + m.logicalWidth))
            readonly property real maxY: Math.max(...shown.map(m => m.y + m.logicalHeight))
            // Room around the screens to drag into
            readonly property real factor: Math.min((width - 120) / (maxX - minX), (height - 80) / (maxY - minY))
            readonly property real offsetX: (width - (maxX - minX) * factor) / 2
            readonly property real offsetY: (height - (maxY - minY) * factor) / 2

            width: parent.width
            height: 240

            PanelText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Drag a screen to move it; it snaps to the others' edges."
                dim: true
                font.pixelSize: Theme.panelFontSize - 2
            }

            Repeater {
                model: canvas.shown

                Rectangle {
                    id: screen

                    required property var modelData
                    readonly property real homeX: canvas.offsetX + (modelData.x - canvas.minX) * canvas.factor
                    readonly property real homeY: canvas.offsetY + (modelData.y - canvas.minY) * canvas.factor - 12

                    x: homeX
                    y: homeY
                    width: modelData.logicalWidth * canvas.factor
                    height: modelData.logicalHeight * canvas.factor
                    radius: 6
                    color: dragArea.containsMouse || dragArea.drag.active ? Theme.surfaceHover : Qt.alpha(Theme.text, 0.12)
                    border.width: 2
                    border.color: dragArea.drag.active ? Theme.accent : Qt.alpha(Theme.text, 0.25)
                    z: dragArea.drag.active ? 1 : 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        PanelText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.displayName(screen.modelData)
                        }

                        PanelText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screen.modelData.name
                            dim: true
                            font.pixelSize: Theme.panelFontSize - 2
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: screen
                        drag.threshold: 4

                        onReleased: {
                            if (Math.abs(screen.x - screen.homeX) < 1 && Math.abs(screen.y - screen.homeY) < 1)
                                return;
                            const x = (screen.x - canvas.offsetX) / canvas.factor + canvas.minX;
                            const y = (screen.y + 12 - canvas.offsetY) / canvas.factor + canvas.minY;
                            const [snappedX, snappedY] = root.snap(screen.modelData, x, y);
                            // Back to its binding until the new layout is read
                            screen.x = Qt.binding(() => screen.homeX);
                            screen.y = Qt.binding(() => screen.homeY);
                            if (snappedX !== screen.modelData.x || snappedY !== screen.modelData.y)
                                Monitors.setPosition(screen.modelData.name, snappedX, snappedY);
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: root.monitors

        SettingsGroup {
            id: monitorGroup

            required property var modelData
            readonly property var monitor: modelData
            readonly property var size: root.splitMode(monitor.mode)
            readonly property string resolution: `${size[0]}x${size[1]}`
            // Resolutions largest first, and the refresh rates of the current one
            readonly property var resolutions: [...new Set(monitor.modes.map(mode => mode.split("@")[0]))]
                .sort((a, b) => {
                    const [aw, ah] = a.split("x").map(Number);
                    const [bw, bh] = b.split("x").map(Number);
                    return bw * bh - aw * ah;
                })
            readonly property var rates: monitor.modes.filter(mode => mode.startsWith(`${resolution}@`))
                .sort((a, b) => root.splitMode(b)[2] - root.splitMode(a)[2])
            readonly property var others: Monitors.monitors.filter(m => m.name !== monitor.name && !m.disabled)

            title: `${root.displayName(monitor)}  ·  ${monitor.name}`

            SettingRow {
                label: "On"
                description: !monitorGroup.monitor.disabled && Monitors.enabledMonitors.length <= 1 ? "The only screen on, so it can't be turned off." : ""

                Toggle {
                    checked: !monitorGroup.monitor.disabled
                    onToggled: Monitors.setEnabled(monitorGroup.monitor.name, !checked)
                }
            }

            Column {
                visible: !monitorGroup.monitor.disabled
                width: parent.width

                SettingRow {
                    label: "Resolution"
                    changed: monitorGroup.monitor.mode !== monitorGroup.monitor.modes[0]
                    onReset: Monitors.setMode(monitorGroup.monitor.name, monitorGroup.monitor.modes[0])

                    Picker {
                        label: monitorGroup.resolution.replace("x", " × ")
                        open: resolutionList.expanded
                        onClicked: resolutionList.toggle()
                    }
                }

                DropdownList {
                    id: resolutionList
                    x: 16
                    width: parent.width - 32
                    // The best refresh rate at each resolution
                    items: monitorGroup.resolutions.map(resolution => ({
                                label: resolution.replace("x", " × "),
                                selected: resolution === monitorGroup.resolution,
                                mode: monitorGroup.monitor.modes.filter(mode => mode.startsWith(`${resolution}@`))
                                    .sort((a, b) => root.splitMode(b)[2] - root.splitMode(a)[2])[0]
                            }))
                    onChosen: item => Monitors.setMode(monitorGroup.monitor.name, item.mode)
                }
            }

            SettingRow {
                visible: !monitorGroup.monitor.disabled && monitorGroup.rates.length > 1
                label: "Refresh rate"

                ChoiceButtons {
                    choices: monitorGroup.rates
                    current: monitorGroup.rates.find(mode => Math.abs(root.splitMode(mode)[2] - monitorGroup.size[2]) < 0.05)
                    format: mode => root.formatRate(root.splitMode(mode)[2])
                    onChosen: mode => Monitors.setMode(monitorGroup.monitor.name, mode)
                }
            }

            SettingRow {
                visible: !monitorGroup.monitor.disabled
                label: "Scale"
                description: "Makes everything bigger; the screen then has less room."
                changed: Math.abs(monitorGroup.monitor.scale - 1) > 0.01
                onReset: Monitors.setScale(monitorGroup.monitor.name, 1)

                ChoiceButtons {
                    choices: Monitors.allScales
                    current: Monitors.allScales.find(scale => Math.abs(scale - monitorGroup.monitor.scale) < 0.01)
                    format: scale => `${scale}×`
                    onChosen: scale => Monitors.setScale(monitorGroup.monitor.name, scale)
                }
            }

            SettingRow {
                visible: !monitorGroup.monitor.disabled
                label: "Rotation"
                changed: monitorGroup.monitor.transform !== 0
                onReset: Monitors.setTransform(monitorGroup.monitor.name, 0)

                ChoiceButtons {
                    choices: [0, 1, 2, 3]
                    current: monitorGroup.monitor.transform % 4
                    format: transform => ["Normal", "90°", "180°", "270°"][transform]
                    onChosen: transform => Monitors.setTransform(monitorGroup.monitor.name, transform)
                }
            }

            SettingRow {
                visible: !monitorGroup.monitor.disabled
                label: "Adaptive sync"
                description: "Lets the screen match games' frame rate (VRR / FreeSync), if it supports it."
                changed: monitorGroup.monitor.vrr
                onReset: Monitors.setVrr(monitorGroup.monitor.name, false)

                Toggle {
                    checked: monitorGroup.monitor.vrr
                    onToggled: Monitors.setVrr(monitorGroup.monitor.name, !checked)
                }
            }

            SettingRow {
                visible: !monitorGroup.monitor.disabled && monitorGroup.others.length > 0
                label: "Mirror"
                description: "Show the same picture as another screen."
                changed: monitorGroup.monitor.mirrorOf !== ""
                onReset: Monitors.setMirror(monitorGroup.monitor.name, "")

                ChoiceButtons {
                    choices: ["", ...monitorGroup.others.map(m => m.name)]
                    current: monitorGroup.monitor.mirrorOf
                    format: name => name === "" ? "Off" : name
                    onChosen: name => Monitors.setMirror(monitorGroup.monitor.name, name)
                }
            }
        }
    }

    SettingsGroup {
        title: "At login"

        SettingRow {
            label: Monitors.hasSaved ? "Using a saved layout" : "Using the default layout"
            description: Monitors.hasSaved ? "Saved from here or the display panel. Changes since aren't kept unless saved again." : "Save to keep this layout after logging out or restarting."

            Row {
                spacing: 8

                PanelButton {
                    visible: Monitors.hasSaved
                    label: "Use defaults"
                    onClicked: Monitors.resetSaved()
                }

                PanelButton {
                    label: "Save this layout"
                    highlighted: true
                    enabled: !Monitors.confirming
                    opacity: enabled ? 1 : 0.4
                    onClicked: Monitors.save()
                }
            }
        }
    }

    SettingsGroup {
        visible: Brightness.available || ExternalBrightness.available
        title: "Brightness"

        SettingRow {
            visible: Brightness.available
            label: "Built-in display"

            Row {
                spacing: 10

                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 260
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
        }

        // External monitors, over DDC (ExternalBrightness)
        Repeater {
            model: ExternalBrightness.displays

            SettingRow {
                id: externalRow

                required property var modelData

                label: externalRow.modelData.name
                description: "Over DDC/CI. Changes reach the monitor once the slider stops."

                Row {
                    spacing: 10

                    Slider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260
                        value: externalRow.modelData.level
                        from: 0
                        to: 1
                        onMoved: value => ExternalBrightness.set(externalRow.modelData.name, value)
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(externalRow.modelData.level * 100)}%`
                        dim: true
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: "Nightlight"

        SettingRow {
            label: "Nightlight"
            description: "Warmer colours, easier on the eyes at night."

            Toggle {
                checked: Nightlight.enabled
                onToggled: Nightlight.setEnabled(!checked)
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("nightlightTemperature")
            onReset: ShellSettings.reset("nightlightTemperature")
            label: "Warmth"
            description: `${ShellSettings.nightlightTemperature} K`

            // Right is warmer: 6000 K down to 2500 K
            Slider {
                width: 260
                value: (6000 - ShellSettings.nightlightTemperature) / 3500
                onMoved: value => ShellSettings.nightlightTemperature = Math.round((6000 - value * 3500) / 100) * 100
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("nightlightSchedule")
            onReset: ShellSettings.reset("nightlightSchedule")
            label: "On a schedule"
            description: "Switching it by hand still works, until the next start or end."

            Toggle {
                checked: ShellSettings.nightlightSchedule
                onToggled: ShellSettings.nightlightSchedule = !checked
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("nightlightEnd") || !ShellSettings.isDefault("nightlightStart")
            onReset: {
                ShellSettings.reset("nightlightEnd");
                ShellSettings.reset("nightlightStart");
            }
            visible: ShellSettings.nightlightSchedule
            sub: true
            label: "From"

            Row {
                spacing: 8

                TimeField {
                    time: ShellSettings.nightlightStart
                    onPicked: value => ShellSettings.nightlightStart = value
                }

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "to"
                    dim: true
                }

                TimeField {
                    time: ShellSettings.nightlightEnd
                    onPicked: value => ShellSettings.nightlightEnd = value
                }
            }
        }
    }

    // A button naming the current choice, with a chevron, that opens a DropdownList
    component Picker: PanelButton {
        property bool open: false

        icon: open ? "\u{F077}" : "\u{F078}"
        highlighted: open
    }

    // "HH:MM", saved when valid and Enter is pressed or it loses focus
    component TimeField: TextField {
        id: timeField

        property string time
        signal picked(string value)

        readonly property bool validTime: /^([01]?\d|2[0-3]):[0-5]\d$/.test(text.trim())

        width: 80
        text: time
        placeholder: "HH:MM"
        valid: validTime
        onAccepted: commit()
        onInputFocusChanged: {
            if (!inputFocus)
                commit();
        }

        function commit(): void {
            if (!validTime)
                return;
            const [hours, minutes] = text.trim().split(":");
            const value = `${hours.padStart(2, "0")}:${minutes}`;
            text = value;
            if (value !== time)
                picked(value);
        }
    }
}

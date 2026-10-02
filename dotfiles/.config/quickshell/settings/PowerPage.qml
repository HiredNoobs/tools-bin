import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

// Settings › Power and idle: power mode, idle timeouts (lock, screen off, suspend; on battery
// and plugged in, through hypridle, see IdleSettings), what closing the lid does (Lid), and
// low battery warnings and actions (LowBattery).
Column {
    id: root

    // Choices for a timeout, in seconds; 0 = never
    readonly property var durations: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200, 10800, 18000]
    readonly property bool battery: Battery.present
    property bool profilesAvailable: false

    function formatDuration(seconds: int): string {
        if (seconds <= 0)
            return "Never";
        // Minutes unless it's a whole or half number of hours (65 min, not 1.1 h)
        if (seconds < 3600 || seconds % 1800 !== 0)
            return `${Math.round(seconds / 60)} min`;
        const hours = seconds / 3600;
        return `${Number.isInteger(hours) ? hours : hours.toFixed(1)} h`;
    }

    spacing: 24

    Process {
        command: ["sh", "-c", "command -v powerprofilesctl"]
        running: true
        onExited: code => root.profilesAvailable = code === 0
    }

    SettingsGroup {
        visible: root.profilesAvailable
        title: "Power mode"

        SettingRow {
            label: "Power mode"
            description: "Saver lowers performance for battery life; Performance the opposite."
            changed: PowerProfiles.profile !== PowerProfile.Balanced
            onReset: PowerProfiles.profile = PowerProfile.Balanced

            ChoiceButtons {
                choices: [PowerProfile.PowerSaver, PowerProfile.Balanced, ...(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : [])]
                current: PowerProfiles.profile
                format: profile => profile === PowerProfile.PowerSaver ? "Saver" : profile === PowerProfile.Balanced ? "Balanced" : "Performance"
                onChosen: profile => PowerProfiles.profile = profile
            }
        }
    }

    SettingsGroup {
        title: "When idle"

        // Column headings over the pickers
        Item {
            width: parent.width
            height: 34

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.bottom: parent.bottom
                spacing: 8

                PanelText {
                    visible: root.battery
                    width: 120
                    horizontalAlignment: Text.AlignHCenter
                    text: "On battery"
                    dim: true
                }

                PanelText {
                    width: 120
                    horizontalAlignment: Text.AlignHCenter
                    text: "Plugged in"
                    dim: true
                }
            }
        }

        IdleRow {
            kind: "lock"
            label: "Lock the screen"
        }

        IdleRow {
            kind: "screen"
            label: "Turn the screen off"
        }

        IdleRow {
            kind: "suspend"
            label: "Suspend"
            description: "Sleep, using almost no power; the screen locks first."
        }
    }

    SettingsGroup {
        visible: Lid.hasLid
        title: "Lid"

        SettingRow {
            changed: !ShellSettings.isDefault("lidAction")
            onReset: ShellSettings.reset("lidAction")
            label: "When the lid closes"

            ChoiceButtons {
                choices: ["suspend", "lock", "nothing"]
                current: ShellSettings.lidAction
                format: action => ({ suspend: "Suspend", lock: "Lock", nothing: "Nothing" })[action]
                onChosen: action => ShellSettings.lidAction = action
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("lidDocked")
            onReset: ShellSettings.reset("lidDocked")
            label: "With another screen connected"
            description: "Screen off keeps working on the other screen with the laptop closed."

            ChoiceButtons {
                choices: ["screen-off", "suspend", "lock", "nothing"]
                current: ShellSettings.lidDocked
                format: action => ({ "screen-off": "Screen off", suspend: "Suspend", lock: "Lock", nothing: "Nothing" })[action]
                onChosen: action => ShellSettings.lidDocked = action
            }
        }
    }

    SettingsGroup {
        visible: root.battery
        title: "Low battery"

        LevelPicker {
            changed: !ShellSettings.isDefault("batteryWarn")
            onReset: ShellSettings.reset("batteryWarn")
            label: "Warn at"
            description: "A notification when the battery gets this low."
            levels: [5, 10, 15, 20, 25, 30, 35, 40]
            current: ShellSettings.batteryWarn
            onPicked: level => ShellSettings.batteryWarn = level
        }

        LevelPicker {
            changed: !ShellSettings.isDefault("batteryCritical")
            onReset: ShellSettings.reset("batteryCritical")
            label: "Critical at"
            levels: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            current: ShellSettings.batteryCritical
            onPicked: level => ShellSettings.batteryCritical = level
        }

        SettingRow {
            changed: !ShellSettings.isDefault("batteryCriticalAction")
            onReset: ShellSettings.reset("batteryCriticalAction")
            label: "Then"
            description: "What happens at the critical level, before the battery runs out."

            ChoiceButtons {
                choices: ["nothing", "suspend", "poweroff"]
                current: ShellSettings.batteryCriticalAction
                format: action => ({ nothing: "Nothing", suspend: "Suspend", poweroff: "Power off" })[action]
                onChosen: action => ShellSettings.batteryCriticalAction = action
            }
        }
    }

    // A timeout on battery and plugged in, each a picker; ↺ when it differs from hypridle.conf
    component IdleRow: Item {
        id: idleRow

        property string kind
        property string label
        property string description: ""

        width: parent.width
        implicitHeight: column.implicitHeight

        Column {
            id: column
            width: parent.width

            SettingRow {
                label: idleRow.label
                description: idleRow.description

                Row {
                    spacing: 8

                    PanelButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: IdleSettings.isCustom(idleRow.kind)
                        icon: "\u{F0E2}"
                        onClicked: IdleSettings.reset(idleRow.kind)
                    }

                    Picker {
                        visible: root.battery
                        kind: idleRow.kind
                        power: "battery"
                        list: batteryList
                        other: acList
                    }

                    Picker {
                        kind: idleRow.kind
                        power: "ac"
                        list: acList
                        other: batteryList
                    }
                }
            }

            DurationList {
                id: batteryList
                kind: idleRow.kind
                power: "battery"
            }

            DurationList {
                id: acList
                kind: idleRow.kind
                power: "ac"
            }
        }
    }

    // A battery level, picked from a list that opens below the row
    component LevelPicker: Column {
        id: levelPicker

        property string label
        property string description: ""
        property var levels: []
        property int current
        property bool changed: false
        signal picked(int level)
        signal reset

        width: parent.width

        SettingRow {
            label: levelPicker.label
            description: levelPicker.description
            changed: levelPicker.changed
            onReset: levelPicker.reset()

            PanelButton {
                width: 90
                label: `${levelPicker.current}%`
                icon: levelList.expanded ? "\u{F077}" : "\u{F078}"
                highlighted: levelList.expanded
                onClicked: levelList.toggle()
            }
        }

        DropdownList {
            id: levelList
            x: 16
            width: parent.width - 32
            items: levelPicker.levels.map(level => ({ label: `${level}%`, selected: level === levelPicker.current, level: level }))
            onChosen: item => levelPicker.picked(item.level)
        }
    }

    // The timeout for one kind and power source, opening its list below the row
    component Picker: PanelButton {
        property string kind
        property string power
        property DropdownList list
        property DropdownList other

        width: 120
        label: root.formatDuration(IdleSettings.get(kind, power))
        icon: list.expanded ? "\u{F077}" : "\u{F078}"
        highlighted: list.expanded
        onClicked: {
            // One list open at a time in a row
            other.setExpanded(false);
            list.toggle();
        }
    }

    // The choices, plus the current and default values if they aren't among them
    component DurationList: DropdownList {
        property string kind
        property string power
        readonly property int current: IdleSettings.get(kind, power)
        readonly property int byDefault: IdleSettings.defaults[kind]?.[power] ?? -1

        x: 16
        width: parent.width - 32
        items: [...new Set([...root.durations, current, ...(byDefault >= 0 ? [byDefault] : [])])]
            .sort((a, b) => a - b)
            .map(seconds => ({
                        label: root.formatDuration(seconds),
                        sublabel: seconds === byDefault ? "Default" : "",
                        selected: seconds === current,
                        seconds: seconds
                    }))
        onChosen: item => IdleSettings.set(kind, power, item.seconds)
    }
}

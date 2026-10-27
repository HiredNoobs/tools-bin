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

        ChoiceRow {
            label: "Power mode"
            description: "Saver lowers performance for battery life; Performance the opposite."
            changed: PowerProfiles.profile !== PowerProfile.Balanced
            onReset: PowerProfiles.profile = PowerProfile.Balanced
            choices: [PowerProfile.PowerSaver, PowerProfile.Balanced, ...(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : [])]
            current: PowerProfiles.profile
            format: profile => profile === PowerProfile.PowerSaver ? "Saver" : profile === PowerProfile.Balanced ? "Balanced" : "Performance"
            onChosen: profile => PowerProfiles.profile = profile
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

        ChoiceRow {
            setting: "lidAction"
            label: "When the lid closes"
            choices: ["suspend", "lock", "nothing"]
            format: action => ({ suspend: "Suspend", lock: "Lock", nothing: "Nothing" })[action]
        }

        ChoiceRow {
            setting: "lidDocked"
            label: "With another screen connected"
            description: "Screen off keeps working on the other screen with the laptop closed."
            choices: ["screen-off", "suspend", "lock", "nothing"]
            format: action => ({ "screen-off": "Screen off", suspend: "Suspend", lock: "Lock", nothing: "Nothing" })[action]
        }
    }

    SettingsGroup {
        visible: root.battery
        title: "Low battery"

        // The warning always comes before the critical level: each offers only the levels on
        // its side of the other, and ↺ stops short of it too
        LevelPicker {
            stateKey: "picker:battery:warn"
            changed: !ShellSettings.isDefault("batteryWarn")
            onReset: ShellSettings.batteryWarn = Math.max(ShellSettings.defaults.batteryWarn, ShellSettings.batteryCritical + 1)
            label: "Warn at"
            description: "A notification when the battery gets this low."
            levels: [5, 10, 15, 20, 25, 30, 35, 40].filter(level => level > ShellSettings.batteryCritical)
            current: ShellSettings.batteryWarn
            onPicked: level => ShellSettings.batteryWarn = level
        }

        LevelPicker {
            stateKey: "picker:battery:critical"
            changed: !ShellSettings.isDefault("batteryCritical")
            onReset: ShellSettings.batteryCritical = Math.min(ShellSettings.defaults.batteryCritical, ShellSettings.batteryWarn - 1)
            label: "Critical at"
            levels: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].filter(level => level < ShellSettings.batteryWarn)
            current: ShellSettings.batteryCritical
            onPicked: level => ShellSettings.batteryCritical = level
        }

        ChoiceRow {
            setting: "batteryCriticalAction"
            label: "Then"
            description: "What happens at the critical level, before the battery runs out."
            choices: ["nothing", "suspend", "poweroff"]
            format: action => ({ nothing: "Nothing", suspend: "Suspend", poweroff: "Power off" })[action]
        }
    }

    // A timeout on battery and plugged in, each a picker opening its list below the row (one
    // at a time); ↺ when either differs from hypridle.conf
    component IdleRow: Column {
        id: idleRow

        property string kind
        property string label
        property string description: ""

        width: parent.width

        SettingRow {
            label: idleRow.label
            description: idleRow.description
            changed: IdleSettings.isCustom(idleRow.kind)
            onReset: IdleSettings.reset(idleRow.kind)

            Row {
                spacing: 8

                IdlePicker {
                    visible: root.battery
                    kind: idleRow.kind
                    power: "battery"
                    list: batteryList
                    other: acList
                }

                IdlePicker {
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

    // A battery level, picked from a list that opens below the row
    component LevelPicker: DropdownRow {
        id: levelPicker

        property var levels: []
        property int current
        signal picked(int level)

        buttonWidth: 90
        buttonLabel: `${current}%`
        items: levels.map(level => ({ label: `${level}%`, selected: level === levelPicker.current, level: level }))
        onChosen: item => levelPicker.picked(item.level)
    }

    // The timeout for one kind and power source
    component IdlePicker: PickerButton {
        property string kind
        property string power
        property DropdownList list
        property DropdownList other

        width: 120
        label: root.formatDuration(IdleSettings.get(kind, power))
        open: list.expanded
        onClicked: {
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

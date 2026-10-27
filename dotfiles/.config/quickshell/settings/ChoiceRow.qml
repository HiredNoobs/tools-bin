import QtQuick
import qs
import qs.components

// A setting picked from a few values: a SettingRow with ChoiceButtons. With `setting` (a
// ShellSettings option) it shows that option, changes it, and its ↺ puts the default back.
// Otherwise the owner sets `current` and `changed`, and handles `chosen` and `reset`.
SettingRow {
    id: root

    property string setting: ""
    property var choices: []
    property var current: setting !== "" ? ShellSettings[setting] : undefined
    // A value's label, and whether it can be picked now
    property var format: value => `${value}`
    property var isEnabled: value => true

    signal chosen(var value)

    changed: setting !== "" && !ShellSettings.isDefault(setting)
    onReset: {
        if (setting !== "")
            ShellSettings.reset(setting);
    }

    ChoiceButtons {
        choices: root.choices
        current: root.current
        format: root.format
        isEnabled: root.isEnabled
        onChosen: value => {
            if (root.setting !== "")
                ShellSettings[root.setting] = value;
            root.chosen(value);
        }
    }
}

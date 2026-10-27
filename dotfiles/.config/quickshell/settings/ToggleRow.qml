import QtQuick
import qs
import qs.components

// A setting that's on or off: a SettingRow with a Toggle. With `setting` (a ShellSettings
// option) it shows that option, changes it, and its ↺ puts the default back. Otherwise the
// owner sets `checked` and `changed`, and handles `toggled` (with the new value) and `reset`.
SettingRow {
    id: root

    property string setting: ""
    property bool checked: setting !== "" ? ShellSettings[setting] : false

    signal toggled(bool on)

    changed: setting !== "" && !ShellSettings.isDefault(setting)
    onReset: {
        if (setting !== "")
            ShellSettings.reset(setting);
    }

    Toggle {
        checked: root.checked
        onToggled: {
            const on = !root.checked;
            if (root.setting !== "")
                ShellSettings[root.setting] = on;
            root.toggled(on);
        }
    }
}

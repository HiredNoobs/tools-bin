import QtQuick
import qs
import qs.components
import qs.services

// Settings › Shell: the control centre, what attaches to the bar, notification pop-ups and the
// clipboard history.
// Saved in ShellSettings and applied straight away.
Column {
    id: root

    readonly property bool attachExpanded: PanelState.isOpen("settings", "attach")

    spacing: 24

    SettingsGroup {
        title: "Bar"

        SettingRow {
            changed: !ShellSettings.isDefault("controlCentre")
            onReset: ShellSettings.reset("controlCentre")
            label: "Control centre"
            description: "The icons on the right of the bar open one panel with a tab for each. Off, each icon opens its own panel."

            Toggle {
                checked: ShellSettings.controlCentre
                onToggled: ShellSettings.controlCentre = !checked
            }
        }
    }

    // A master switch, then which drop-downs it applies to, listed under it when expanded
    // (remembered for the session). Detached ones go back to their own place, described on each.
    SettingsGroup {
        title: "Attach to the bar"

        SettingRow {
            changed: !ShellSettings.isDefault("attachToBar")
            onReset: ShellSettings.reset("attachToBar")
            label: "Attach to the bar"
            description: "Drop-downs hang from the bar's bottom edge, joined by curved corners. Off, none of them are."
            expandable: true
            expanded: root.attachExpanded
            onExpandToggled: PanelState.toggle("settings", "attach")

            Toggle {
                checked: ShellSettings.attachToBar
                onToggled: ShellSettings.attachToBar = !checked
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("attachPanels")
            onReset: ShellSettings.reset("attachPanels")
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            label: "Bar icon panels"
            description: "Off, they float just below their icon."

            Toggle {
                checked: ShellSettings.attachPanels
                onToggled: ShellSettings.attachPanels = !checked
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("attachLauncher")
            onReset: ShellSettings.reset("attachLauncher")
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            label: "Launcher and menus"
            description: "The launcher (Super+Space), screenshot menu (Print) and wallpaper picker, under the clock. Off, they open in the middle of the screen."

            Toggle {
                checked: ShellSettings.attachLauncher
                onToggled: ShellSettings.attachLauncher = !checked
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("attachPopups")
            onReset: ShellSettings.reset("attachPopups")
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            label: "Notification pop-ups"
            description: "Off, they float in the top-right corner."

            Toggle {
                checked: ShellSettings.attachPopups
                onToggled: ShellSettings.attachPopups = !checked
            }
        }

        SettingRow {
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            changed: !ShellSettings.isDefault("attachOsd")
            onReset: ShellSettings.reset("attachOsd")
            label: "Volume and brightness pop-up"
            description: "Off, it floats near the bottom of the screen."

            Toggle {
                checked: ShellSettings.attachOsd
                onToggled: ShellSettings.attachOsd = !checked
            }
        }
    }

    SettingsGroup {
        title: "Notifications"

        SettingRow {
            changed: !ShellSettings.isDefault("popupSeconds")
            onReset: ShellSettings.reset("popupSeconds")
            label: "Pop-up duration"
            description: "How long a notification stays on screen, unless it asks for longer. Urgent ones stay until dismissed."

            ChoiceButtons {
                choices: [3, 5, 8, 10]
                current: ShellSettings.popupSeconds
                format: seconds => `${seconds} s`
                onChosen: value => ShellSettings.popupSeconds = value
            }
        }

        SettingRow {
            changed: !ShellSettings.isDefault("maxPopups")
            onReset: ShellSettings.reset("maxPopups")
            label: "Pop-ups at once"
            description: "More wait their turn."

            ChoiceButtons {
                choices: [1, 2, 3, 4, 5]
                current: ShellSettings.maxPopups
                onChosen: value => ShellSettings.maxPopups = value
            }
        }
    }

    SettingsGroup {
        title: "Clipboard"

        SettingRow {
            changed: !ShellSettings.isDefault("clipboardHistory")
            onReset: ShellSettings.reset("clipboardHistory")
            label: "Clipboard history"
            description: "Super+V lists what you've copied. Kept in memory only, until the shell restarts; copies a password manager marks as secret are never kept."

            Toggle {
                checked: ShellSettings.clipboardHistory
                onToggled: ShellSettings.clipboardHistory = !checked
            }
        }

        SettingRow {
            visible: ShellSettings.clipboardHistory
            label: "Clear the history"
            description: `${Clipboard.entries.length} kept.`

            PanelButton {
                icon: "\u{F0A7A}"
                label: "Clear"
                onClicked: Clipboard.clear()
            }
        }
    }
}

import QtQuick
import qs
import qs.components
import qs.services

// Settings › Shell: the control centre, what attaches to the bar, and notification pop-ups.
// Saved in ShellSettings and applied straight away.
Column {
    id: root

    readonly property bool attachExpanded: PanelState.isOpen("settings", "attach")

    spacing: 24

    SettingsGroup {
        title: "Bar"

        SettingRow {
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
    }

    SettingsGroup {
        title: "Notifications"

        SettingRow {
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
            label: "Pop-ups at once"
            description: "More wait their turn."

            ChoiceButtons {
                choices: [1, 2, 3, 4, 5]
                current: ShellSettings.maxPopups
                onChosen: value => ShellSettings.maxPopups = value
            }
        }
    }
}

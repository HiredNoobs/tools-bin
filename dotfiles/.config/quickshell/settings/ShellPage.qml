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

        ToggleRow {
            setting: "controlCentre"
            label: "Control centre"
            description: "The icons on the right of the bar open one panel with a tab for each. Off, each icon opens its own panel."
        }
    }

    // A master switch, then which drop-downs it applies to, listed under it when expanded
    // (remembered for the session). Detached ones go back to their own place, described on each.
    SettingsGroup {
        title: "Attach to the bar"

        ToggleRow {
            setting: "attachToBar"
            label: "Attach to the bar"
            description: "Drop-downs hang from the bar's bottom edge, joined by curved corners. Off, none of them are."
            expandable: true
            expanded: root.attachExpanded
            onExpandToggled: PanelState.toggle("settings", "attach")
        }

        ToggleRow {
            setting: "attachPanels"
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            label: "Bar icon panels"
            description: "Off, they float just below their icon."
        }

        ToggleRow {
            setting: "attachLauncher"
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            label: "Launcher and menus"
            description: "The launcher (Super+Space), screenshot menu (Print) and wallpaper picker, under the clock. Off, they open in the middle of the screen."
        }

        ToggleRow {
            setting: "attachPopups"
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            label: "Notification pop-ups"
            description: "Off, they float in the top-right corner."
        }

        ToggleRow {
            setting: "attachOsd"
            visible: root.attachExpanded
            sub: true
            enabled: ShellSettings.attachToBar
            label: "Volume and brightness pop-up"
            description: "Off, it floats near the bottom of the screen."
        }
    }

    SettingsGroup {
        title: "Notifications"

        ChoiceRow {
            setting: "popupSeconds"
            label: "Pop-up duration"
            description: "How long a notification stays on screen, unless it asks for longer. Urgent ones stay until dismissed."
            choices: [3, 5, 8, 10]
            format: seconds => `${seconds} s`
        }

        ChoiceRow {
            setting: "maxPopups"
            label: "Pop-ups at once"
            description: "More wait their turn."
            choices: [1, 2, 3, 4, 5]
        }
    }

    SettingsGroup {
        title: "Clipboard"

        ToggleRow {
            setting: "clipboardHistory"
            label: "Clipboard history"
            description: "Super+V lists what you've copied. Kept in memory only, until the shell restarts; copies a password manager marks as secret are never kept."
        }

        ToggleRow {
            setting: "clipboardSkipPasswords"
            visible: ShellSettings.clipboardHistory
            sub: true
            label: "Skip anything that looks like a password"
            description: "Text with no spaces that mixes at least three of capitals, small letters, numbers and symbols (generated passwords, keys, tokens), for password managers that don't mark what they copy as secret. Passphrases can slip through: an app clearing the clipboard (Bitwarden's \"Clear clipboard\" option) also removes what it held."
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

    SettingsGroup {
        title: "Reload"

        SettingRow {
            label: "Hyprland"
            description: "Reads its config files again."

            PanelButton {
                icon: "\u{F01E}"
                label: "Reload"
                onClicked: Exec.run("hyprctl reload")
            }
        }

        // A fresh start rather than a hot reload, which proved unreliable
        SettingRow {
            label: "Quickshell"
            description: "Starts the shell again; this window comes back where it was."

            PanelButton {
                icon: "\u{F01E}"
                label: "Restart"
                onClicked: RestartState.restartShell()
            }
        }
    }
}

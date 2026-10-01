import QtQuick
import qs.components
import qs.services

// Opened from the Arch button: system stats, monitoring tools and theme settings
Column {
    id: root

    signal closeRequested

    function run(action: var): void {
        action();
        closeRequested();
    }

    width: 300
    spacing: 10

    // Laptop only
    PanelSection {
        visible: Battery.present
        text: "Battery"
    }

    StatBar {
        visible: Battery.present
        width: parent.width
        icon: Battery.icon
        label: Battery.status
        value: `${Battery.capacity}%`
        fraction: Battery.capacity / 100
        barColour: Battery.colour
    }

    PanelSection {
        text: "System"
    }

    StatBar {
        width: parent.width
        icon: "\u{F0EE0}"
        label: "CPU"
        value: `${SysStats.cpuUsage}%`
        fraction: SysStats.cpuUsage / 100
    }

    StatBar {
        width: parent.width
        icon: "\u{EFC5}"
        label: "Memory"
        value: `${SysStats.memUsedGiB.toFixed(1)}G / ${SysStats.memTotalGiB.toFixed(1)}G`
        fraction: SysStats.memTotalGiB > 0 ? SysStats.memUsedGiB / SysStats.memTotalGiB : 0
    }

    StatBar {
        width: parent.width
        icon: "\u{F2C9}"
        label: "Temperature"
        value: `${SysStats.temperature}°C`
        fraction: SysStats.temperature / 100
    }

    PanelSection {
        text: "Monitoring"
    }

    Row {
        spacing: 8

        PanelButton {
            label: "htop"
            onClicked: root.run(() => Exec.floating("kitty htop", true))
        }

        PanelButton {
            label: "nvtop"
            onClicked: root.run(() => Exec.floating("kitty nvtop", true))
        }
    }

    PanelSection {
        text: "Theme"
    }

    Flow {
        width: parent.width
        spacing: 8

        PanelButton {
            label: "Wallpaper"
            onClicked: root.run(() => Exec.run("~/.config/rofi/scripts/wallpaper-menu.sh"))
        }

        PanelButton {
            label: "GTK"
            onClicked: root.run(() => Exec.floating("nwg-look", false))
        }

        PanelButton {
            label: "QT6"
            onClicked: root.run(() => Exec.floating("qt6ct", false))
        }

        PanelButton {
            label: "Kvantum"
            onClicked: root.run(() => Exec.floating("kvantummanager", false))
        }
    }

    Item {
        width: parent.width
        height: 4
    }

    PanelButton {
        width: parent.width
        icon: "\u{F01E}"
        label: "Reload Hyprland"
        onClicked: root.run(() => Exec.run("hyprctl reload"))
    }

    // Same actions as the old wlogout menu
    PanelSection {
        text: "Power"
    }

    Flow {
        width: parent.width
        spacing: 8

        PowerButton {
            icon: "\u{F023}"
            name: "Lock"
            command: "hyprlock"
        }

        PowerButton {
            icon: "\u{23FE}"
            name: "Sleep"
            command: "systemctl suspend-then-hibernate || systemctl suspend"
        }

        PowerButton {
            icon: "\u{F0343}"
            name: "Logout"
            command: "hyprshutdown -t 'Logging out...'"
            needsConfirm: true
        }

        PowerButton {
            icon: "\u{EAD2}"
            name: "Reboot"
            command: "hyprshutdown -t 'Rebooting...' --post-cmd 'systemctl reboot'"
            needsConfirm: true
        }

        PowerButton {
            icon: "\u{23FB}"
            name: "Shutdown"
            command: "hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff'"
            needsConfirm: true
        }
    }

    // Runs `command`. With `needsConfirm`, the first click asks "Confirm?" for 3s and a
    // second click runs it, so a stray click in the panel can't end the session.
    component PowerButton: PanelButton {
        id: powerButton

        property string command
        property bool needsConfirm: false
        property string name
        property bool armed: false

        highlighted: armed
        label: armed ? "Confirm?" : name
        onClicked: {
            if (needsConfirm && !armed) {
                armed = true;
                disarmTimer.restart();
                return;
            }
            armed = false;
            root.run(() => Exec.run(command));
        }

        Timer {
            id: disarmTimer
            interval: 3000
            onTriggered: powerButton.armed = false
        }
    }
}

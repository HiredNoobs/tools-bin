import QtQuick
import qs.components
import qs.services

BarText {
    id: root

    text: "\u{F08C7}"
    leftPadding: 15
    onRightClicked: menu.toggle()

    ActionMenu {
        id: menu
        target: root
        items: [
            {
                label: "System monitoring",
                children: [
                    { label: "htop", action: () => Exec.floating("kitty htop", true) },
                    { label: "nvtop", action: () => Exec.floating("kitty nvtop", true) }
                ]
            },
            {
                label: "Theme",
                children: [
                    { label: "Wallpaper", command: "~/.config/rofi/scripts/wallpaper-menu.sh" },
                    { label: "GTK", action: () => Exec.floating("nwg-look", false) },
                    { label: "QT6", action: () => Exec.floating("qt6ct", false) },
                    { label: "Kvantum", action: () => Exec.floating("kvantummanager", false) }
                ]
            },
            { separator: true },
            { label: "\u{F01E} Reload hyprland", command: "hyprctl reload" }
        ]
    }
}

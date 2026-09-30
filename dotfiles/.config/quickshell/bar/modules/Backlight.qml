import QtQuick
import Quickshell.Io
import qs.components
import qs.services

// Hidden on machines without the intel_backlight device (e.g. the desktop)
BarText {
    id: root

    readonly property string device: "/sys/class/backlight/intel_backlight"
    property int brightness: 0
    property int maxBrightness: 0
    readonly property int percent: maxBrightness > 0 ? Math.round(100 * brightness / maxBrightness) : 0
    readonly property var icons: ["\u{F00DE}", "\u{F00DF}", "\u{F00E0}"]

    visible: maxBrightness > 0
    width: Math.max(implicitWidth, 60)
    hoverable: false
    text: `${icons[Math.min(icons.length - 1, Math.floor(percent / 100 * icons.length))]} ${percent}%`

    onScrolledUp: Exec.run("brightnessctl set 1%+")
    onScrolledDown: Exec.run("brightnessctl --min-value=10000 set 1%-")
    onRightClicked: menu.toggle()

    // sysfs doesn't send change notifications, so poll
    Timer {
        interval: 500
        running: root.maxBrightness > 0
        repeat: true
        onTriggered: brightnessFile.reload()
    }

    FileView {
        id: brightnessFile
        path: root.device + "/brightness"
        printErrors: false
        onLoaded: root.brightness = Number(text())
    }

    FileView {
        path: root.device + "/max_brightness"
        printErrors: false
        onLoaded: root.maxBrightness = Number(text())
    }

    ActionMenu {
        id: menu
        target: root
        items: [
            { label: "Toggle nightlight", command: "~/.config/quickshell/scripts/toggle-nightlight.sh" }
        ]
    }
}

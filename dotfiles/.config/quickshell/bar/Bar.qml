import QtQuick
import Quickshell
import qs
import qs.bar.modules

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 7
        left: 10
        right: 10
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.alpha(Theme.background, 0.6)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
    }

    Row {
        anchors.left: parent.left
        height: parent.height

        Arch {}
        Clock {}
        Spacer {}
        Cpu {}
        Memory {}
        Temperature {}
    }

    Workspaces {
        anchors.centerIn: parent
        height: parent.height
        screen: root.screen
    }

    Row {
        anchors.right: parent.right
        height: parent.height

        TrayDrawer {}
        Backlight {}
        Audio {}
        Audio {
            source: true
        }
        Bluetooth {}
        Network {}
        Battery {}
        Power {}
    }
}

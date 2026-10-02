import QtQuick
import qs
import qs.components
import qs.services

// "Keep these display settings?" under the clock on every screen, after a change that could
// blank one (Monitors.guard) from the settings window or the display panel. Going back happens
// by itself when the count runs out.
Rectangle {
    id: root

    readonly property bool shown: Monitors.confirming

    x: (parent.width - width) / 2
    y: Theme.barHeight + Theme.panelGap
    width: row.implicitWidth + 32
    height: shown ? row.implicitHeight + 24 : 0
    radius: Theme.radius
    color: Theme.panelBackground
    border.width: 2
    border.color: Theme.warning
    opacity: shown ? 1 : 0
    visible: opacity > 0
    clip: true

    Behavior on opacity {
        NumberAnimation { duration: Theme.panelAnimDuration }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: `\u{F0379}  Keep these display settings? Going back in ${Monitors.revertIn} s`
        }

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            label: "Go back"
            onClicked: Monitors.revert()
        }

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            label: "Keep"
            highlighted: true
            onClicked: Monitors.keep()
        }
    }
}

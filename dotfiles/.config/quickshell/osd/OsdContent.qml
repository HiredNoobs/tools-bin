import QtQuick
import qs
import qs.components
import qs.services

// What the on-screen display shows (OsdState): icon, level bar (marked at 100% when volume can
// go above it) and the percentage, or "Off" when muted
Row {
    spacing: 14

    PanelText {
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        horizontalAlignment: Text.AlignHCenter
        text: OsdState.icon
        font.pixelSize: Theme.fontSize + 4
        color: OsdState.muted ? Theme.subtext : Theme.text
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 190
        height: 6
        radius: 3
        color: Theme.surface

        Rectangle {
            width: parent.width * Math.min(1, OsdState.level / OsdState.full)
            height: parent.height
            radius: parent.radius
            color: OsdState.muted ? Theme.subtext : OsdState.level > 1.005 ? Theme.warning : Theme.accent

            Behavior on width {
                NumberAnimation { duration: 100 }
            }
        }

        Rectangle {
            visible: OsdState.full > 1
            x: parent.width / OsdState.full - 1
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 12
            radius: 1
            color: Theme.subtext
        }
    }

    PanelText {
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: OsdState.muted ? "Off" : `${Math.round(OsdState.level * 100)}%`
        dim: true
    }
}

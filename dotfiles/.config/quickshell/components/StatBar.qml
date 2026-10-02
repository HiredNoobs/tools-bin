import QtQuick
import qs

// Label, value and a thin usage bar (fraction 0..1). With `clickable`, hovering lights the
// label and a click emits `clicked` (e.g. to open a monitor sorted by that resource).
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property real fraction: 0
    property color barColour: Theme.accent
    property bool clickable: false

    signal clicked

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: labelText.implicitHeight

            PanelText {
                id: labelText
                text: `${root.icon}  ${root.label}`
                color: mouse.containsMouse ? Theme.accent : Theme.text
            }

            PanelText {
                anchors.right: parent.right
                text: root.value
                dim: true
            }
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Theme.surface

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.fraction))
                height: parent.height
                radius: parent.radius
                color: root.barColour

                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        // A little taller, so the gap down to the bar is part of it
        anchors.margins: -3
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

import QtQuick
import qs

// Label, value and a thin usage bar (fraction 0..1)
Column {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property real fraction: 0
    property color barColour: Theme.accent

    spacing: 4

    Item {
        width: parent.width
        height: labelText.implicitHeight

        PanelText {
            id: labelText
            text: `${root.icon}  ${root.label}`
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

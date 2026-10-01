import QtQuick
import qs

// Rounded button with an optional icon; `highlighted` keeps it in the accent colour
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool highlighted: false
    readonly property alias hovered: mouse.containsMouse
    signal clicked

    implicitWidth: content.implicitWidth + 20
    implicitHeight: content.implicitHeight + 12
    radius: 8
    color: hovered ? Theme.surfaceHover : Theme.surface

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        PanelText {
            visible: root.icon !== ""
            text: root.icon
            color: root.hovered || root.highlighted ? Theme.accent : Theme.text
        }

        PanelText {
            visible: root.label !== ""
            text: root.label
            color: root.hovered || root.highlighted ? Theme.accent : Theme.text
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

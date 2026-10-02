import QtQuick
import qs

// On/off switch. Emits `toggled`; the owner updates `checked`.
Rectangle {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.accent : Theme.surface

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        width: 16
        height: 16
        radius: 8
        color: root.checked ? Theme.background : Theme.text

        Behavior on x {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        // Disabled (e.g. a greyed-out setting) it keeps the arrow
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled()
    }
}

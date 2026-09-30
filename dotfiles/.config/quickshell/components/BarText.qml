import QtQuick
import Quickshell
import qs

// A bar label with Waybar's shared padding, colours and hover behaviour
Text {
    id: root

    property bool hoverable: true
    property string tooltip: ""
    readonly property alias hovered: mouse.containsMouse

    signal leftClicked
    signal rightClicked
    signal scrolledUp
    signal scrolledDown

    height: parent ? parent.height : Theme.barHeight
    leftPadding: 5
    rightPadding: 5
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: hoverable && hovered ? Theme.accent : Theme.text

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.leftClicked()
        onWheel: event => event.angleDelta.y > 0 ? root.scrolledUp() : root.scrolledDown()
    }

    LazyLoader {
        active: root.tooltip !== "" && root.hovered

        Tooltip {
            target: root
            text: root.tooltip
        }
    }
}

import QtQuick
import Quickshell
import qs

// A bar label with the bar's shared padding, colours and hover behaviour
Text {
    id: root

    property bool hoverable: true
    // Its panel is open
    property bool active: false
    property string tooltip: ""
    readonly property alias hovered: mouse.containsMouse

    signal leftClicked
    signal rightClicked

    // Fixed width with the glyph centred (0 = fit the text), so an icon that changes glyph
    // (e.g. the bell during Do Not Disturb) can't shift its neighbours
    property int slotWidth: 0

    width: slotWidth > 0 ? slotWidth : implicitWidth
    height: parent ? parent.height : Theme.barHeight
    leftPadding: slotWidth > 0 ? 0 : 5
    rightPadding: slotWidth > 0 ? 0 : 5
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    // Colour when not open or hovered (e.g. the Arch logo showing low battery)
    property color restingColour: Theme.text

    color: active || (hoverable && hovered) ? Theme.accent : restingColour

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.leftClicked()
    }

    LazyLoader {
        active: root.tooltip !== "" && root.hovered && !root.active

        Tooltip {
            target: root
            text: root.tooltip
        }
    }
}

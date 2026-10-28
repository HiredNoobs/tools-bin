import QtQuick
import qs

// A glyph that's a button (✕ to dismiss, a tick, a chevron): no background, lit while hovered
// or `lit`, and a click area a little bigger than the glyph
PanelText {
    id: root

    property bool lit: false
    property color restColour: Theme.subtext
    property real hitMargin: -4
    readonly property alias hovered: mouse.containsMouse

    signal clicked

    color: hovered || lit ? Theme.accent : restColour

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: root.hitMargin
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

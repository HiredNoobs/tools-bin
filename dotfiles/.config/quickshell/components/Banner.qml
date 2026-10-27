import QtQuick
import qs

// A message across the top of a page, shown while `text` isn't empty: an error (`tone:
// "critical"`, the default) or a warning, with an icon. Buttons put inside sit on its right;
// `closable` adds a ✕ that emits `closed` (the owner clears the text).
Rectangle {
    id: root

    property string text: ""
    property string tone: "critical"
    property string icon: "\u{F0026}"
    property bool closable: false
    default property alias actions: actionRow.data

    signal closed

    readonly property color toneColour: tone === "warning" ? Theme.warning : Theme.critical

    visible: text !== ""
    width: parent?.width ?? 0
    height: Math.max(message.implicitHeight, actionRow.height) + 24
    radius: Theme.radius
    color: Qt.alpha(toneColour, 0.15)

    PanelText {
        id: message
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 32 - (actionRow.width > 0 ? actionRow.width + 12 : 0)
        text: root.icon !== "" ? `${root.icon}  ${root.text}` : root.text
        wrapMode: Text.WordWrap
        color: root.toneColour
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        PanelText {
            visible: root.closable
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F00D}"
            color: closeMouse.containsMouse ? Theme.text : root.toneColour

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closed()
            }
        }
    }
}

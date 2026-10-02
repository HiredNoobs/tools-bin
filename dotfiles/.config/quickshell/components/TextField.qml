import QtQuick
import qs

// A one-line text box with a placeholder, like the connectivity panel's password field. With
// `valid: false` (e.g. a malformed address) its border turns red. Enter emits `accepted`.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool valid: true
    readonly property alias inputFocus: input.activeFocus
    signal accepted

    implicitWidth: 260
    implicitHeight: 34
    radius: 8
    color: Theme.surface
    border.width: !valid ? 1 : input.activeFocus ? 1 : 0
    border.color: !valid ? Theme.critical : Theme.accent

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        color: Theme.text
        selectionColor: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelFontSize
        clip: true
        onAccepted: root.accepted()

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            dim: true
        }
    }

    // The whole box focuses the text
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: event => {
            input.forceActiveFocus();
            event.accepted = false;
        }
    }
}

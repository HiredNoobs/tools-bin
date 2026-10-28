import QtQuick
import qs

// A one-line text box with a placeholder. With `valid: false` (e.g. a malformed address) its
// border turns red. Enter emits `accepted`; with `escapeCancels`, Esc emits `escaped` and
// goes no further (otherwise it reaches the panel or window, which leaves the field).
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool valid: true
    property bool escapeCancels: false
    readonly property alias inputFocus: input.activeFocus
    signal accepted
    signal escaped

    function focusInput(): void {
        input.forceActiveFocus();
    }

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
        Keys.onEscapePressed: event => {
            if (root.escapeCancels)
                root.escaped();
            else
                event.accepted = false;
        }

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

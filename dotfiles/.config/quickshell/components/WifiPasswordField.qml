import QtQuick
import qs

// A Wi-Fi network's password with a Connect button, under a secured network in the
// connectivity panel and Settings › Network. Empty and focused each time it shows; Enter or
// Connect connects (`submitted`), Esc gives up (`cancelled`) rather than closing the panel.
Row {
    id: root

    property var network
    // The field's width; with `fill`, whatever the button leaves of the row
    property bool fill: false
    property real fieldWidth: fill ? width - connectButton.width - spacing : 300

    signal submitted
    signal cancelled

    function submit(): void {
        if (field.text === "")
            return;
        network.connectWithPsk(field.text);
        field.text = "";
        submitted();
    }

    spacing: 8

    onVisibleChanged: {
        if (visible) {
            field.text = "";
            field.focusInput();
        }
    }

    TextField {
        id: field
        width: root.fieldWidth
        placeholder: "Password"
        password: true
        escapeCancels: true
        onAccepted: root.submit()
        onEscaped: root.cancelled()
    }

    PanelButton {
        id: connectButton
        anchors.verticalCenter: parent.verticalCenter
        label: "Connect"
        highlighted: true
        enabled: field.text !== ""
        opacity: enabled ? 1 : 0.4
        onClicked: root.submit()
    }
}

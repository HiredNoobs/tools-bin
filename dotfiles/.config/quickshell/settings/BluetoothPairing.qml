import QtQuick
import qs
import qs.components
import qs.services

// The Bluetooth pairing window's content (PairingWindow), for the request BluetoothAgent is
// waiting on: check a code matches, allow a device, enter a PIN or passkey, or (keyboards) type
// a code on the device. Enter accepts, Esc rejects; answering closes the window.
Column {
    id: root

    readonly property var request: BluetoothAgent.request
    readonly property string type: request?.type ?? ""
    readonly property bool needsInput: type === "pin" || type === "passkey"

    function accept(): void {
        if (needsInput && field.text.trim() === "")
            return;
        BluetoothAgent.answer(true, needsInput ? field.text.trim() : "");
    }

    function reject(): void {
        BluetoothAgent.answer(false, "");
    }

    width: 380
    spacing: 14

    Component.onCompleted: Qt.callLater(() => needsInput ? field.forceActiveFocus() : root.forceActiveFocus())

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape)
            root.reject();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.type === "display" ? root.reject() : root.accept();
        else
            return;
        event.accepted = true;
    }

    PanelText {
        width: parent.width
        text: `\u{F00AF}  ${root.type === "authorize" ? `${root.request?.device} wants to pair` : `Pair with ${root.request?.device}`}`
        font.pixelSize: Theme.fontSize + 2
        elide: Text.ElideRight
    }

    PanelText {
        width: parent.width
        wrapMode: Text.WordWrap
        dim: true
        text: {
            switch (root.type) {
            case "confirm":
                return `Check this code matches the one shown on ${root.request?.device}:`;
            case "authorize":
                return "Allow it to pair with this computer?";
            case "pin":
                return `Enter its PIN (often 0000 or 1234, or see its manual):`;
            case "passkey":
                return "Enter the passkey shown on it:";
            case "display":
                return `Type this code on ${root.request?.device}, then press Enter on it:`;
            }
            return "";
        }
    }

    // The code to compare or type
    PanelText {
        visible: (root.request?.code ?? "") !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        text: (root.request?.code ?? "").split("").join(" ")
        font.pixelSize: Theme.fontSize + 14
        color: Theme.accent
    }

    // Keys typed so far, while a keyboard is being paired
    PanelText {
        visible: root.type === "display" && root.request?.entered !== undefined
        anchors.horizontalCenter: parent.horizontalCenter
        text: `${root.request?.entered ?? 0} typed`
        dim: true
    }

    TextField {
        id: field
        visible: root.needsInput
        width: parent.width
        placeholder: root.type === "pin" ? "PIN" : "Passkey"
        onAccepted: root.accept()
    }

    Row {
        anchors.right: parent.right
        spacing: 8

        PanelButton {
            label: root.type === "display" ? "Cancel" : root.type === "authorize" ? "Deny" : "Reject"
            onClicked: root.reject()
        }

        PanelButton {
            visible: root.type !== "display"
            label: root.type === "authorize" ? "Allow" : "Pair"
            highlighted: true
            onClicked: root.accept()
        }
    }
}

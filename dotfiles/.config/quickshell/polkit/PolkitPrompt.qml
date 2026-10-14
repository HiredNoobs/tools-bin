import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs
import qs.components

// The authentication agent, in place of hyprpolkitagent: when an app asks for an admin action
// (pkexec, NetworkManager, udisks, …) a card over the focused screen asks for the password.
// Enter (or Authenticate) answers, Esc (or Cancel, or a click outside) declines; a wrong
// password shakes the card and asks again.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property AuthFlow flow: agent.flow
    // What went wrong last ("" for nothing)
    property string error: ""

    Connections {
        target: root.flow

        function onAuthenticationFailed(): void {
            root.error = "Wrong password";
            card.shake();
        }

        function onIsResponseRequiredChanged(): void {
            if (root.flow.isResponseRequired) {
                field.text = "";
                field.focusInput();
            }
        }
    }

    onFlowChanged: error = ""

    function submit(): void {
        if (flow && flow.isResponseRequired && field.text !== "") {
            error = "";
            flow.submit(field.text);
        }
    }

    function cancel(): void {
        flow?.cancelAuthenticationRequest();
    }

    PanelWindow {
        id: window

        visible: agent.isActive
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        color: Qt.alpha("black", 0.45)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible) {
                field.text = "";
                field.focusInput();
            }
        }

        // A click outside the card declines
        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }

        Rectangle {
            id: card

            property real offset: 0

            function shake(): void {
                shakeAnim.restart();
            }

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: offset
            width: 420
            height: body.implicitHeight + 48
            radius: 16
            color: Theme.panelBackground
            border.width: 2
            border.color: Theme.accent

            Keys.onEscapePressed: root.cancel()

            SequentialAnimation {
                id: shakeAnim
                loops: 2
                NumberAnimation { target: card; property: "offset"; to: -10; duration: 50 }
                NumberAnimation { target: card; property: "offset"; to: 10; duration: 100 }
                NumberAnimation { target: card; property: "offset"; to: 0; duration: 50 }
            }

            // Clicks on the card stay on it
            MouseArea {
                anchors.fill: parent
                onClicked: field.focusInput()
            }

            Column {
                id: body
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 14

                Row {
                    spacing: 12

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F0341}"
                        color: Theme.accent
                        font.pixelSize: 22
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Authentication required"
                        font.pixelSize: 17
                        font.bold: true
                    }
                }

                PanelText {
                    width: parent.width
                    text: root.flow?.message ?? ""
                    wrapMode: Text.WordWrap
                }

                PanelText {
                    width: parent.width
                    visible: text !== ""
                    text: root.flow?.actionId ?? ""
                    elide: Text.ElideMiddle
                    dim: true
                    font.pixelSize: 12
                }

                TextField {
                    id: field
                    width: parent.width
                    implicitHeight: 40
                    password: !(root.flow?.responseVisible ?? false)
                    placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                    onAccepted: root.submit()
                }

                // Wrong password, or what polkit has to say
                PanelText {
                    width: parent.width
                    visible: text !== ""
                    text: root.error !== "" ? root.error : root.flow?.supplementaryMessage ?? ""
                    color: root.error !== "" || root.flow?.supplementaryIsError ? Theme.critical : Theme.subtext
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    PanelButton {
                        label: "Cancel"
                        onClicked: root.cancel()
                    }

                    PanelButton {
                        icon: "\u{F0341}"
                        label: "Authenticate"
                        highlighted: true
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}

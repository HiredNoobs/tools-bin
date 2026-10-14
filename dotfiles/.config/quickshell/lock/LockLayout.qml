import QtQuick
import QtQuick.Effects

// The lock and login screen's look, shared by the Quickshell lockscreen (LockContent feeds it)
// and the SDDM theme (setup copies this file there), so the two can't drift apart. Plain
// QtQuick only, for that reason, and fixed pixel sizes, which hyprlock.conf mirrors for when
// hyprlock stands in.
// Centred: a big clock and the date above a card with the avatar, a greeting and the password
// box. Along the bottom: the track playing (with its controls), battery, network, how many
// notifications are waiting, and the power buttons (those marked `confirm` ask for a second
// click).
Item {
    id: root

    // Look
    property url wallpaper
    property color background: "#282828"
    property color text: "#d5c4a1"
    property color accent: "#fb4934"
    property color critical: "#f53c3c"
    property color warning: "#ffbe61"
    property string fontFamily: "CodeNewRoman Nerd Font Propo"
    readonly property color subtext: Qt.alpha(text, 0.6)
    readonly property color surface: Qt.alpha(text, 0.08)
    readonly property color surfaceHover: Qt.alpha(accent, 0.2)
    readonly property color cardColour: Qt.alpha(background, 0.97)

    // Who
    property string userName: ""
    // Tried in turn until one loads; the name's initial if none does
    property var avatars: []

    // The password box
    property string password: ""
    property bool busy: false
    property string message: ""
    property bool capsLock: false
    signal submitted
    // Any key in the box (e.g. to check Caps Lock again)
    signal keyPressed

    // Status along the bottom; a pill with nothing to show is hidden
    property bool batteryPresent: false
    property string batteryIcon: ""
    property int batteryCapacity: 0
    property color batteryColour: text
    property string networkIcon: ""
    property string networkName: ""
    property int notificationCount: 0

    property bool mediaVisible: false
    property string mediaText: ""
    property bool mediaPlaying: false
    property bool canPrevious: false
    property bool canToggle: false
    property bool canNext: false
    signal mediaPrevious
    signal mediaToggle
    signal mediaNext

    // Login only (the SDDM theme): clicking the name switches user, and with more than one
    // session a button before the power buttons opens a list of them upwards. Off (and empty) on
    // the lockscreen.
    property bool userSwitchable: false
    signal userClicked
    property var sessions: []
    property int sessionIndex: 0
    signal sessionPicked(int index)

    // [{ icon, name, confirm }]; `powerAction(name)` once confirmed
    property var powerActions: []
    signal powerAction(string name)

    // Bumped on each wrong password, to shake the card
    property int failures: 0
    onFailuresChanged: shakeAnim.restart()

    function focusInput(): void {
        input.forceActiveFocus();
    }

    // Sizes, mirrored by hyprlock.conf
    readonly property int clockSize: 140
    readonly property int cardWidth: 360
    readonly property int cardHeight: 300
    // The card's centre below the screen's
    readonly property int cardOffset: 90
    readonly property int pillHeight: 44
    readonly property int bottomMargin: 32

    Component.onCompleted: input.forceActiveFocus()

    // --- Background

    // Both reach past the screen's edges, so the blur's dark rim (it fades into the nothing beyond
    // the picture) is off screen
    Image {
        id: wallpaperImage
        anchors.fill: parent
        anchors.margins: -64
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        anchors.margins: -64
        source: wallpaperImage
        visible: wallpaperImage.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.1
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.background, 0.35)
    }

    // --- Clock

    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Text {
        id: time
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: date.top
        text: Qt.formatTime(root.now, "HH:mm")
        color: root.text
        font.family: root.fontFamily
        font.pixelSize: root.clockSize
        font.bold: true
    }

    Text {
        id: date
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: 44
        text: Qt.formatDate(root.now, "dddd, d MMMM")
        color: root.subtext
        font.family: root.fontFamily
        font.pixelSize: 24
    }

    // --- The card

    Rectangle {
        id: card

        property real shake: 0

        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.cardOffset
        anchors.horizontalCenterOffset: shake
        width: root.cardWidth
        height: root.cardHeight
        radius: 20
        color: root.cardColour
        border.width: 2
        border.color: root.accent

        SequentialAnimation {
            id: shakeAnim
            loops: 2
            NumberAnimation { target: card; property: "shake"; to: -10; duration: 50 }
            NumberAnimation { target: card; property: "shake"; to: 10; duration: 100 }
            NumberAnimation { target: card; property: "shake"; to: 0; duration: 50 }
        }

        // Clicking the card gives the box focus back
        MouseArea {
            anchors.fill: parent
            onClicked: input.forceActiveFocus()
        }

        // Avatar, round
        Item {
            id: avatarItem
            anchors.horizontalCenter: parent.horizontalCenter
            y: 28
            width: 96
            height: 96

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.surface
            }

            Image {
                id: avatar
                property int attempt: 0
                anchors.fill: parent
                source: root.avatars[attempt] ?? ""
                // Changed in Settings at the same path
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 192
                sourceSize.height: 192
                visible: false
                onStatusChanged: {
                    if (status === Image.Error && attempt < root.avatars.length)
                        attempt++;
                }
            }

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: avatar
                visible: avatar.status === Image.Ready
                maskEnabled: true
                maskSource: avatarMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Text {
                visible: avatar.status !== Image.Ready
                anchors.centerIn: parent
                text: root.userName.charAt(0).toUpperCase()
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 40
            }
        }

        Text {
            id: greeting
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: avatarItem.bottom
            anchors.topMargin: 14
            text: root.userSwitchable ? `Hi, ${root.userName}  \u{F0140}` : `Hi, ${root.userName}`
            color: greetingMouse.containsMouse ? root.accent : root.text
            font.family: root.fontFamily
            font.pixelSize: 20

            MouseArea {
                id: greetingMouse
                anchors.fill: parent
                enabled: root.userSwitchable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.userClicked()
            }
        }

        // Password box
        Rectangle {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: greeting.bottom
            anchors.topMargin: 16
            width: parent.width - 56
            height: 44
            radius: 22
            color: root.surface
            border.width: 1
            border.color: root.message !== "" ? root.critical : input.activeFocus ? root.accent : "transparent"

            TextInput {
                id: input
                // Centred in the box, clear of the arrow on either side
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 44
                anchors.rightMargin: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: TextInput.AlignHCenter
                // No caret, as hyprlock has none
                cursorDelegate: Item {}
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: root.text
                selectionColor: root.accent
                font.family: root.fontFamily
                font.pixelSize: 15
                readOnly: root.busy
                clip: true
                focus: true

                // Kept in step with `password`, which other screens may change
                onTextChanged: {
                    if (text !== root.password)
                        root.password = text;
                }
                onAccepted: root.submitted()
                Keys.onPressed: event => {
                    root.keyPressed();
                    if (event.key === Qt.Key_Escape) {
                        if (sessionMenu.open)
                            sessionMenu.open = false;
                        else
                            root.password = "";
                        event.accepted = true;
                    }
                }

                Connections {
                    target: root
                    function onPasswordChanged() {
                        if (input.text !== root.password)
                            input.text = root.password;
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: input.text === ""
                    text: "Password"
                    color: root.subtext
                    font.family: root.fontFamily
                    font.pixelSize: 15
                }
            }

            RoundButton {
                id: submit
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                icon: root.busy ? "\u{F0453}" : "\u{F0054}"
                spinning: root.busy
                onClicked: root.submitted()
            }
        }

        // Checking, wrong password, Caps Lock
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: box.bottom
            anchors.topMargin: 12
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.busy ? "Checking…" : root.message !== "" ? root.message : root.capsLock ? "\u{F0632}  Caps Lock is on" : ""
            color: root.busy ? root.subtext : root.message !== "" ? root.critical : root.warning
            font.family: root.fontFamily
            font.pixelSize: 14
        }
    }

    // --- Along the bottom

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomMargin
        spacing: 12

        Pill {
            visible: root.mediaVisible

            Label {
                text: "\u{F075A}"
                color: root.accent
            }

            Label {
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
                text: root.mediaText
            }

            RoundButton {
                icon: "\u{F04AE}"
                enabled: root.canPrevious
                onClicked: root.mediaPrevious()
            }

            RoundButton {
                icon: root.mediaPlaying ? "\u{F03E4}" : "\u{F040A}"
                enabled: root.canToggle
                onClicked: root.mediaToggle()
            }

            RoundButton {
                icon: "\u{F04AD}"
                enabled: root.canNext
                onClicked: root.mediaNext()
            }
        }

        Pill {
            Label {
                visible: root.batteryPresent
                text: `${root.batteryIcon} ${root.batteryCapacity}%`
                color: root.batteryColour
            }

            Label {
                visible: root.networkIcon !== ""
                text: root.networkName !== "" ? `${root.networkIcon}  ${root.networkName}` : root.networkIcon
            }

            Label {
                visible: root.notificationCount > 0
                text: `\u{F009A} ${root.notificationCount}`
            }
        }

        Pill {
            visible: root.powerActions.length > 0 || root.sessions.length > 1

            RoundButton {
                id: sessionButton
                visible: root.sessions.length > 1
                icon: "\u{F0379}"
                label: `${root.sessions[root.sessionIndex] ?? ""}  ${sessionMenu.open ? "\u{F0140}" : "\u{F0143}"}`
                highlighted: sessionMenu.open
                onClicked: sessionMenu.open = !sessionMenu.open
            }

            Repeater {
                model: root.powerActions

                RoundButton {
                    id: action

                    required property var modelData
                    property bool armed: false

                    icon: modelData.icon
                    label: armed ? `${modelData.name}?` : ""
                    highlighted: armed
                    onClicked: {
                        if (modelData.confirm && !armed) {
                            armed = true;
                            disarm.restart();
                            return;
                        }
                        armed = false;
                        root.powerAction(modelData.name);
                    }

                    Timer {
                        id: disarm
                        interval: 3000
                        onTriggered: action.armed = false
                    }
                }
            }
        }
    }

    // --- The session list, above the session button

    // A click anywhere else closes it
    MouseArea {
        anchors.fill: parent
        visible: sessionMenu.open
        onClicked: sessionMenu.open = false
    }

    Rectangle {
        id: sessionMenu

        property bool open: false
        // Where the button is, found on opening (the bottom row moves as its pills change)
        property point anchor: Qt.point(0, 0)

        onOpenChanged: {
            if (open)
                anchor = sessionButton.mapToItem(root, sessionButton.width / 2, 0);
            input.forceActiveFocus();
        }

        // Centred over the button, clear of the pill it sits in, and kept on screen
        x: Math.max(8, Math.min(root.width - width - 8, anchor.x - width / 2))
        y: anchor.y - (root.pillHeight - sessionButton.height) / 2 - 10 - height + (open ? 0 : 8)
        // The widest name, plus the tick's room and padding (a Column sizes from its rows' widths,
        // which follow the list's, so it can't say)
        property real widest: 0
        width: Math.max(200, widest + 36 + 16 + 12)
        height: sessionList.implicitHeight + 12
        radius: 16
        color: root.cardColour
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.5)
        opacity: open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Column {
            id: sessionList
            anchors.centerIn: parent
            width: parent.width - 12

            Repeater {
                model: root.sessions

                Rectangle {
                    id: sessionItem

                    required property string modelData
                    required property int index
                    readonly property bool current: index === root.sessionIndex

                    width: sessionList.width
                    height: 36
                    radius: 10
                    color: itemMouse.containsMouse ? root.surfaceHover : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sessionItem.current
                        text: "\u{F012C}"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        id: sessionLabel
                        anchors.left: parent.left
                        anchors.leftMargin: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: sessionItem.modelData
                        onImplicitWidthChanged: sessionMenu.widest = Math.max(sessionMenu.widest, implicitWidth)
                        Component.onCompleted: sessionMenu.widest = Math.max(sessionMenu.widest, implicitWidth)
                        color: itemMouse.containsMouse || sessionItem.current ? root.accent : root.text
                        font.family: root.fontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sessionPicked(sessionItem.index);
                            sessionMenu.open = false;
                        }
                    }
                }
            }
        }
    }

    // --- Pieces

    // A rounded strip along the bottom
    component Pill: Rectangle {
        default property alias items: pillRow.data

        height: root.pillHeight
        width: pillRow.implicitWidth + 28
        radius: root.pillHeight / 2
        color: root.cardColour

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 12
        }
    }

    component Label: Text {
        anchors.verticalCenter: parent?.verticalCenter
        color: root.text
        font.family: root.fontFamily
        font.pixelSize: 14
    }

    // An icon (and a label while armed) in a circle that lights up under the pointer
    component RoundButton: Rectangle {
        id: button

        property string icon
        property string label: ""
        property bool highlighted: false
        property int size: 30
        property bool spinning: false
        signal clicked

        anchors.verticalCenter: parent?.verticalCenter
        width: label !== "" ? content.implicitWidth + 20 : size
        height: size
        radius: size / 2
        color: mouse.containsMouse || highlighted ? root.surfaceHover : "transparent"
        opacity: enabled ? 1 : 0.4

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6

            Text {
                id: glyph
                text: button.icon
                color: mouse.containsMouse || button.highlighted ? root.accent : root.text
                font.family: root.fontFamily
                font.pixelSize: 14

                RotationAnimation on rotation {
                    running: button.spinning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onStopped: glyph.rotation = 0
                }
            }

            Text {
                visible: button.label !== ""
                text: button.label
                color: mouse.containsMouse || button.highlighted ? root.accent : root.text
                font.family: root.fontFamily
                font.pixelSize: 14
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}

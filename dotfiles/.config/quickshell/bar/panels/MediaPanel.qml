import QtQuick
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Opened from the now-playing label on the bar, and the control centre's Media tab: the
// active player (playerctld's, as the media keys use), its seek bar and controls, and any
// other sources. Clicking a track takes you to its app.
Column {
    id: root

    signal closeRequested

    readonly property var player: Media.player
    property bool othersOpen: false

    function openApp(target: var): void {
        Media.open(target);
        closeRequested();
    }

    width: 360
    spacing: 12

    PanelSection {
        text: "Now playing"
    }

    PanelText {
        visible: !root.player
        text: "Nothing playing"
        dim: true
    }

    // Art, title, artist, album; click to go to the app
    Rectangle {
        visible: root.player !== null
        width: parent.width
        height: track.implicitHeight + 12
        radius: 8
        color: trackMouse.containsMouse ? Theme.surfaceHover : "transparent"

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        MouseArea {
            id: trackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openApp(root.player)
        }

        Row {
            id: track
            x: 6
            y: 6
            width: parent.width - 12
            spacing: 12

            ClippingRectangle {
                id: art
                visible: artImage.status === Image.Ready
                width: 72
                height: 72
                radius: 8
                color: Theme.surface

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 144
                    sourceSize.height: 144
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (art.visible ? art.width + parent.spacing : 0)
                spacing: 2

                // Title, artist and album wrap rather than cut off, so they can be read in full here
                PanelText {
                    width: parent.width
                    text: root.player?.trackTitle || root.player?.identity || ""
                    font.bold: true
                    wrapMode: Text.Wrap
                }

                PanelText {
                    visible: text !== ""
                    width: parent.width
                    text: root.player?.trackArtist ?? ""
                    wrapMode: Text.Wrap
                }

                PanelText {
                    visible: text !== ""
                    width: parent.width
                    text: root.player?.trackAlbum ?? ""
                    dim: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.panelFontSize - 1
                }
            }
        }
    }

    // Seek bar with times
    Column {
        visible: (root.player?.lengthSupported ?? false) && root.player.length > 0
        width: parent.width
        spacing: 2

        Slider {
            width: parent.width
            from: 0
            to: root.player?.length ?? 1
            value: root.player?.position ?? 0
            enabled: root.player?.canSeek ?? false
            moveOnRelease: true
            scrollStep: 5
            onMoved: value => {
                if (root.player?.canSeek)
                    root.player.position = value;
            }
        }

        Item {
            width: parent.width
            height: elapsed.implicitHeight

            PanelText {
                id: elapsed
                text: Media.formatTime(root.player?.position ?? 0)
                dim: true
                font.pixelSize: Theme.panelFontSize - 2
            }

            PanelText {
                anchors.right: parent.right
                text: Media.formatTime(root.player?.length ?? 0)
                dim: true
                font.pixelSize: Theme.panelFontSize - 2
            }
        }
    }

    // Previous, play/pause, next
    Row {
        visible: root.player !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "\u{F04AE}"
            opacity: root.player?.canGoPrevious ? 1 : 0.4
            onClicked: {
                if (root.player?.canGoPrevious)
                    root.player.previous();
            }
        }

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 52
            implicitHeight: 40
            icon: root.player?.isPlaying ? "\u{F03E4}" : "\u{F040A}"
            highlighted: true
            onClicked: {
                if (root.player?.canTogglePlaying)
                    root.player.togglePlaying();
            }
        }

        PanelButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "\u{F04AD}"
            opacity: root.player?.canGoNext ? 1 : 0.4
            onClicked: {
                if (root.player?.canGoNext)
                    root.player.next();
            }
        }
    }

    // Takes you to the player's window, even on another workspace
    // Other sources, only when there's more than one; slides open like the other drop-downs
    ListRow {
        visible: Media.others.length > 0
        width: parent.width
        label: "Other sources"
        sublabel: Media.others.map(p => p.identity).join(", ")
        selected: root.othersOpen
        onClicked: root.othersOpen = !root.othersOpen

        PanelText {
            text: root.othersOpen ? "\u{F077}" : "\u{F078}"
            color: root.othersOpen ? Theme.accent : Theme.subtext
            font.pixelSize: Theme.panelFontSize - 3
        }
    }

    Item {
        visible: Media.others.length > 0
        width: parent.width
        height: root.othersOpen ? otherList.implicitHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
        }

        Column {
            id: otherList
            width: parent.width
            spacing: 2

            Repeater {
                model: Media.others

                // Click to go to the app; the button plays or pauses it (which makes it the
                // active player, as with the media keys)
                ListRow {
                    id: other

                    required property var modelData

                    x: 16
                    width: otherList.width - 16
                    label: modelData.trackTitle || modelData.identity
                    sublabel: [modelData.trackArtist, modelData.identity].filter(part => part).join(" \u00B7 ")
                    onClicked: root.openApp(modelData)

                    PanelButton {
                        icon: other.modelData.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                        onClicked: {
                            if (other.modelData.canTogglePlaying)
                                other.modelData.togglePlaying();
                        }
                    }
                }
            }
        }
    }
}

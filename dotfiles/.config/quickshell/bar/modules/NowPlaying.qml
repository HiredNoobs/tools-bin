import QtQuick
import qs
import qs.services

// What's playing, next to the workspaces: "♫ Title · Artist", shown while a player has a
// track. Normal colour while playing, dimmed while paused. Capped in width with "…"; hovering
// a cut-off label scrolls the title (the ♫ stays put) so the whole thing can be read. Opens the
// media panel (wired up in Bar.qml).
Item {
    id: root

    // Same interface as BarText, which the other bar modules use
    property bool active: false
    signal leftClicked

    readonly property var player: Media.player
    readonly property string artist: player?.trackArtist ?? ""
    readonly property int maxWidth: 320
    readonly property int padding: 5
    // Between the ♫ and the title
    readonly property int gap: 8
    readonly property color colour: active || mouse.containsMouse ? Theme.accent : player?.isPlaying ? Theme.text : Theme.subtext

    // The title area: whatever's left of the width after the ♫
    readonly property real titleSpace: maxWidth - 2 * padding - icon.implicitWidth - gap
    readonly property bool overflowing: label.implicitWidth > titleSpace
    readonly property bool scrolling: mouse.containsMouse && overflowing
    // How far left the title has scrolled
    property real offset: 0

    visible: Media.hasTrack
    width: 2 * padding + icon.implicitWidth + gap + Math.min(label.implicitWidth, titleSpace)
    height: parent ? parent.height : Theme.barHeight

    onScrollingChanged: {
        if (!scrolling)
            offset = 0;
    }

    Text {
        id: icon

        x: root.padding
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        text: "\u{F075A}"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: root.colour

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // Clips the title as it scrolls
    Item {
        id: titleArea

        x: icon.x + icon.implicitWidth + root.gap
        width: root.width - x - root.padding
        height: parent.height
        clip: true

        Text {
            id: label

            x: -root.offset
            height: parent.height
            // Full length while scrolling, cut off with "…" otherwise
            width: root.scrolling ? implicitWidth : titleArea.width
            elide: root.scrolling ? Text.ElideNone : Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            text: `${root.player?.trackTitle ?? ""}${root.artist ? `  ·  ${root.artist}` : ""}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: root.colour

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    // Pause, scroll to the end at a steady reading speed, pause, scroll back; repeat
    SequentialAnimation {
        id: marquee

        running: root.scrolling
        loops: Animation.Infinite

        readonly property real distance: Math.max(0, label.implicitWidth - titleArea.width)

        PauseAnimation { duration: 600 }
        NumberAnimation {
            target: root
            property: "offset"
            to: marquee.distance
            duration: marquee.distance * 25
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 1200 }
        NumberAnimation {
            target: root
            property: "offset"
            to: 0
            duration: marquee.distance * 10
            easing.type: Easing.InOutSine
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.leftClicked()
    }
}

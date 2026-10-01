import QtQuick
import qs
import qs.components
import qs.services

// Bell (crossed out during Do Not Disturb) with an unread count.
// Left click opens the notification center (wired up in Bar.qml).
BarText {
    id: root

    readonly property int unread: Notifications.unread

    text: Notifications.dnd ? "\u{F009B}" : "\u{F009A}"

    // Unread count; a plain dot past 9
    Rectangle {
        visible: root.unread > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 1
        width: root.unread > 9 ? 8 : Math.max(14, count.implicitWidth + 6)
        height: root.unread > 9 ? 8 : 14
        radius: height / 2
        color: Theme.accent

        Text {
            id: count
            visible: root.unread <= 9
            anchors.centerIn: parent
            text: root.unread
            color: Theme.background
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
        }
    }
}

import QtQuick
import Quickshell.Services.SystemTray
import qs
import qs.components

// One icon standing in for all tray apps, hidden when none are running. Opens the apps
// panel (wired up in Bar.qml). A dot shows when any app needs attention (e.g. unread messages).
BarText {
    id: root

    readonly property var items: SystemTray.items.values
    readonly property bool needsAttention: items.some(item => item.status === Status.NeedsAttention)

    visible: items.length > 0
    text: "\u{F107}"
    tooltip: items.map(item => item.tooltipTitle || item.title || item.id).join("\n")

    Rectangle {
        visible: root.needsAttention
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 7
        anchors.rightMargin: 2
        width: 7
        height: 7
        radius: 3.5
        color: Theme.accent
    }
}

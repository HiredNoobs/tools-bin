import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.services

// One notification: icon or image, summary, body, time, actions and dismiss.
// Clicking the card runs the app's "default" action if it has one.
Rectangle {
    id: root

    required property var notification
    // Popups cut long bodies short; the center shows them in full
    property int maxBodyLines: 0
    readonly property alias hovered: mouse.containsMouse

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var actions: Array.from(notification?.actions ?? [])
    readonly property var defaultAction: actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: actions.filter(a => a.identifier !== "default")

    // Image if the app sent one (e.g. a screenshot), else the app's icon; nothing rather than
    // a placeholder when neither resolves
    readonly property string iconSource: {
        const n = notification;
        if (!n)
            return "";
        for (let name of [n.image, n.appIcon, DesktopEntries.byId(n.desktopEntry)?.icon ?? ""]) {
            if (!name)
                continue;
            if (name.startsWith("/"))
                return `file://${name}`;
            // Icon names can also arrive as "image://icon/<name>" (udiskie does this); those
            // still need checking, or a missing one draws the placeholder texture
            if (name.startsWith("image://icon/"))
                name = name.slice("image://icon/".length);
            else if (name.includes("://"))
                return name;
            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
        }
        return "";
    }

    function timeAgo(): string {
        const at = Notifications.received[notification?.id];
        if (!at)
            return "";
        const minutes = Math.floor((clock.date.getTime() - at) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes}m`;
        return `${Math.floor(minutes / 60)}h`;
    }

    implicitHeight: content.implicitHeight + 20
    radius: 8
    color: mouse.containsMouse && root.defaultAction ? Theme.surfaceHover : Theme.surface

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.defaultAction)
                Notifications.invoke(root.notification, root.defaultAction);
        }
    }

    // Critical: accent edge, like dunst's red frame
    Rectangle {
        visible: root.critical
        width: 3
        height: parent.height - 16
        anchors.verticalCenter: parent.verticalCenter
        x: 3
        radius: 1.5
        color: Theme.accent
    }

    Row {
        id: content
        x: 12
        y: 10
        width: parent.width - 24
        spacing: 10

        IconImage {
            id: icon
            visible: root.iconSource !== ""
            implicitSize: 36
            source: root.iconSource
        }

        Column {
            width: parent.width - (icon.visible ? icon.width + parent.spacing : 0)
            spacing: 4

            // Summary, time, dismiss
            Item {
                width: parent.width
                height: summary.implicitHeight

                PanelText {
                    id: summary
                    width: parent.width - time.width - dismiss.width - 16
                    text: root.notification?.summary || root.notification?.appName || ""
                    font.bold: true
                    elide: Text.ElideRight
                    color: root.critical ? Theme.accent : Theme.text
                }

                PanelText {
                    id: time
                    anchors.right: dismiss.left
                    anchors.rightMargin: 8
                    text: root.timeAgo()
                    dim: true
                    font.pixelSize: Theme.panelFontSize - 2
                }

                PanelText {
                    id: dismiss
                    anchors.right: parent.right
                    text: "\u{F00D}"
                    color: dismissMouse.containsMouse ? Theme.accent : Theme.subtext

                    MouseArea {
                        id: dismissMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.dismiss(root.notification)
                    }
                }
            }

            PanelText {
                visible: text !== ""
                width: parent.width
                // Its markup (bold, links…) without pictures, which could be fetched from
                // anywhere
                text: (root.notification?.body ?? "").replace(/<img\b[^>]*>/gi, "")
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.maxBodyLines > 0 ? root.maxBodyLines : 1000
                elide: Text.ElideRight
                dim: true
                linkColor: Theme.accent
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                visible: root.buttons.length > 0
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.buttons

                    PanelButton {
                        required property var modelData
                        label: modelData.text
                        onClicked: Notifications.invoke(root.notification, modelData)
                    }
                }
            }
        }
    }
}

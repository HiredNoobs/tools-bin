import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Notification center: notifications grouped by app, Do Not Disturb and Clear all.
// Self-contained so it can later become a tab of a combined control centre.
Column {
    id: root

    signal closeRequested

    // Expanded app groups (see PanelState). Groups start collapsed, so the center opens as a
    // list of apps rather than filling the screen, and stay open for the session once opened
    function toggleGroup(app: string): void {
        PanelState.toggle("notifications", app);
    }

    function iconFor(group: var): string {
        for (const name of [group.icon, DesktopEntries.byId(group.desktopEntry)?.icon ?? ""]) {
            if (!name)
                continue;
            if (name.startsWith("/"))
                return `file://${name}`;
            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
        }
        return "";
    }

    width: 380
    spacing: 10

    // Seen while it's open, including what comes in meanwhile
    Component.onCompleted: Notifications.markRead()

    Connections {
        target: Notifications

        function onListChanged(): void {
            Notifications.markRead();
        }
    }

    // Heading with Do Not Disturb on the right
    Item {
        width: parent.width
        height: dndRow.implicitHeight

        PanelSection {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
        }

        Row {
            id: dndRow
            anchors.right: parent.right
            spacing: 8

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Do not disturb"
                dim: true
                font.pixelSize: Theme.panelFontSize - 1
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Notifications.dnd
                onToggled: Notifications.dnd = !Notifications.dnd
            }
        }
    }

    PanelText {
        visible: Notifications.list.length === 0
        text: "No notifications"
        dim: true
    }

    // Groups, scrolling when long
    Flickable {
        visible: Notifications.list.length > 0
        width: parent.width
        height: Math.min(groupColumn.implicitHeight, 520)
        contentHeight: groupColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: groupColumn
            width: parent.width
            spacing: 8

            // Kept by app, so a new notification doesn't make every group and card again
            Repeater {
                model: ScriptModel {
                    values: Notifications.groups.map(group => group.app)
                }

                Column {
                    id: group

                    required property string modelData
                    readonly property var info: Notifications.groups.find(g => g.app === modelData) ?? { app: modelData, notifications: [] }
                    readonly property bool open: PanelState.isOpen("notifications", modelData)

                    width: groupColumn.width
                    spacing: 4

                    ListRow {
                        width: parent.width
                        iconSource: root.iconFor(group.info)
                        label: group.modelData
                        sublabel: `${group.info.notifications.length} notification${group.info.notifications.length === 1 ? "" : "s"}`
                        onClicked: root.toggleGroup(group.modelData)

                        Row {
                            spacing: 10

                            PanelText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: group.open ? "\u{F077}" : "\u{F078}"
                                color: Theme.subtext
                                font.pixelSize: Theme.panelFontSize - 3
                            }

                            // Dismiss the whole group
                            PanelText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u{F00D}"
                                color: groupDismiss.containsMouse ? Theme.accent : Theme.subtext

                                MouseArea {
                                    id: groupDismiss
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Notifications.dismissGroup(group.modelData)
                                }
                            }
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: group.open ? group.info.notifications : []
                        }

                        NotificationCard {
                            required property var modelData
                            notification: modelData
                            x: 12
                            width: group.width - 12
                        }
                    }
                }
            }
        }
    }

    PanelButton {
        visible: Notifications.list.length > 0
        width: parent.width
        icon: "\u{F1F8}"
        label: "Clear all"
        onClicked: Notifications.clearAll()
    }
}

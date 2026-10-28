import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Notification center: notifications grouped by app, Do Not Disturb and Clear all. Its own
// panel, or the control centre's Notifications tab.
Column {
    id: root

    signal closeRequested

    // How tall the groups get before they scroll, under the heading and above Clear all; the
    // control centre lets them grow, as its tab scrolls already
    property real maxListHeight: 520

    // Expanded app groups (see PanelState). Groups start collapsed, so the center opens as a
    // list of apps rather than filling the screen, and stay open for the session once opened
    function toggleGroup(app: string): void {
        PanelState.toggle("notifications", app);
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
    PanelHeading {
        text: "Notifications"

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

    PanelText {
        visible: Notifications.list.length === 0
        text: "No notifications"
        dim: true
    }

    // Groups, scrolling when long
    Flickable {
        id: groupList
        visible: Notifications.list.length > 0
        width: parent.width
        height: Math.min(groupColumn.implicitHeight, root.maxListHeight)
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
                        iconSource: Icons.resolve([group.info.icon, DesktopEntries.byId(group.info.desktopEntry)?.icon ?? ""])
                        label: group.modelData
                        sublabel: `${group.info.notifications.length} notification${group.info.notifications.length === 1 ? "" : "s"}`
                        onClicked: root.toggleGroup(group.modelData)

                        Row {
                            spacing: 10

                            ExpandChevron {
                                anchors.verticalCenter: parent.verticalCenter
                                expanded: group.open
                            }

                            // Dismiss the whole group
                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u{F00D}"
                                onClicked: Notifications.dismissGroup(group.modelData)
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

    ScrollIndicator {
        flickable: groupList
    }

    PanelButton {
        visible: Notifications.list.length > 0
        width: parent.width
        icon: "\u{F1F8}"
        label: "Clear all"
        onClicked: Notifications.clearAll()
    }
}

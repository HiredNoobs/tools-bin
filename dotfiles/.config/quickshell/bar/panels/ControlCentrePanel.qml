import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services

// One panel with a tab per right-hand bar icon (Theme.controlCentre). Each tab shows that
// icon's own panel. Fixed width so the tab row stays put; the height fits the tab.
Column {
    id: root

    property string tab: "notifications"

    signal closeRequested
    signal tabRequested(string name)

    // Same order as the icons on the bar; Apps and Drives only while there's something in them
    readonly property var tabs: [
        ...(SystemTray.items.values.length > 0 ? [{ name: "apps", icon: "\u{F003B}", label: "Apps" }] : []),
        ...(Drives.drives.length > 0 ? [{ name: "drives", icon: "\u{F02CA}", label: "Drives" }] : []),
        { name: "audio", icon: "\u{F028}", label: "Sound" },
        { name: "connectivity", icon: Theme.wifiIcon(1), label: "Network" },
        { name: "display", icon: "\u{F0379}", label: "Display" },
        { name: "notifications", icon: Notifications.dnd ? "\u{F009B}" : "\u{F009A}", label: "Notifications" }
    ]
    readonly property int tabIndex: Math.max(0, tabs.findIndex(t => t.name === tab))

    // The open tab went away (e.g. last drive ejected): fall back to Notifications
    onTabsChanged: {
        if (!tabs.some(t => t.name === tab))
            tabRequested("notifications");
    }

    width: 400
    spacing: 12

    // Tab row with a sliding underline
    Item {
        width: parent.width
        height: tabRow.height + 4

        Row {
            id: tabRow

            Repeater {
                model: root.tabs

                MouseArea {
                    id: tabButton

                    required property var modelData
                    readonly property bool current: modelData.name === root.tab

                    width: root.width / root.tabs.length
                    height: 32
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabRequested(modelData.name)

                    PanelText {
                        anchors.centerIn: parent
                        text: tabButton.modelData.icon
                        font.pixelSize: Theme.panelFontSize + 3
                        color: tabButton.current || tabButton.containsMouse ? Theme.accent : Theme.subtext

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Unread count on the notifications tab
                    Rectangle {
                        visible: tabButton.modelData.name === "notifications" && Notifications.unread > 0 && !tabButton.current
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: 9
                        y: 4
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Theme.accent
                    }

                    LazyLoader {
                        active: tabButton.containsMouse

                        Tooltip {
                            target: tabButton
                            text: tabButton.modelData.label
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            x: root.tabIndex * (root.width / root.tabs.length) + 12
            width: root.width / root.tabs.length - 24
            height: 2
            radius: 1
            color: Theme.accent

            Behavior on x {
                NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
            }
        }
    }

    Loader {
        id: content
        width: parent.width
        sourceComponent: ({
            "notifications": notificationsTab,
            "audio": audioTab,
            "connectivity": connectivityTab,
            "display": displayTab,
            "drives": drivesTab,
            "apps": appsTab
        })[root.tab] ?? null
        onLoaded: fadeIn.restart()
    }

    NumberAnimation {
        id: fadeIn
        target: content
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }

    Component {
        id: notificationsTab
        NotificationsPanel {
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: audioTab
        AudioPanel {
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: connectivityTab
        ConnectivityPanel {
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: displayTab
        DisplayPanel {
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: drivesTab
        DrivesPanel {
            closeWhenEmpty: false
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: appsTab
        AppsPanel {
            closeWhenEmpty: false
            onCloseRequested: root.closeRequested()
        }
    }
}

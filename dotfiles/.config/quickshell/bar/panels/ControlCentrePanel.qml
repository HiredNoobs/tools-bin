import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services

// One panel with a tab per right-hand bar icon (Theme.controlCentre), under the quick toggles.
// Each tab shows that icon's own panel. Fixed width so the tab row stays put; the height fits
// the tab, which scrolls under the toggles and tab row when it's taller than the room left.
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
        { name: "notifications", icon: Notifications.dnd ? "\u{F009B}" : "\u{F009A}", label: "Notifications", dot: Notifications.unread > 0 }
    ]

    // The open tab went away (e.g. last drive ejected), or was asked for with nothing in it
    // (IPC): fall back to Notifications
    function checkTab(): void {
        if (!tabs.some(t => t.name === tab))
            tabRequested("notifications");
    }
    onTabsChanged: checkTab()
    Component.onCompleted: checkTab()

    // The most the whole panel may be (the bar sets it for its screen)
    property real maxHeight: Theme.panelMaxHeight

    width: 400
    spacing: 12

    // What's left of the panel's height for the tab
    readonly property real tabRoom: maxHeight - 2 * Theme.panelPadding - toggles.height - tabBar.height - 2 * spacing

    onTabChanged: {
        scroller.contentY = 0;
        // Once this change is done: asking for another tab from inside it is a binding loop
        Qt.callLater(checkTab);
    }

    QuickToggles {
        id: toggles
        width: parent.width
    }

    TabBar {
        id: tabBar
        width: parent.width
        tabs: root.tabs
        current: root.tab
        onTabRequested: name => root.tabRequested(name)
    }

    Flickable {
        id: scroller
        width: parent.width
        height: Math.min(content.height, root.tabRoom)
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // A tab's own closeRequested closes the whole panel
        FadeLoader {
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
            onCloseRequested: root.closeRequested()
        }
    }

    ScrollIndicator {
        flickable: scroller
        margin: 0
    }

    Component {
        id: notificationsTab
        NotificationsPanel {
            maxListHeight: Number.POSITIVE_INFINITY
        }
    }

    Component {
        id: audioTab
        AudioPanel {}
    }

    Component {
        id: connectivityTab
        ConnectivityPanel {}
    }

    Component {
        id: displayTab
        DisplayPanel {}
    }

    Component {
        id: drivesTab
        DrivesPanel {
            closeWhenEmpty: false
        }
    }

    Component {
        id: appsTab
        AppsPanel {
            closeWhenEmpty: false
        }
    }
}

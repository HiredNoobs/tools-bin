import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services

// One panel with a tab per right-hand bar icon (Theme.controlCentre), under the quick toggles
// and usage. Each tab shows that icon's own panel. Fixed width so the tab row stays put; the
// height fits the tab.
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

    // The open tab went away (e.g. last drive ejected): fall back to Notifications
    onTabsChanged: {
        if (!tabs.some(t => t.name === tab))
            tabRequested("notifications");
    }

    width: 400
    spacing: 12

    QuickToggles {
        width: parent.width
    }

    TabBar {
        width: parent.width
        tabs: root.tabs
        current: root.tab
        onTabRequested: name => root.tabRequested(name)
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

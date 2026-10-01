import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.bar.modules
import qs.bar.panels
import qs.components

// The bar plus the drop-down panel area below it. The window is taller than the bar,
// but only the bar, the open panel and notification popups take input (see `mask`).
PanelWindow {
    id: root

    required property ShellScreen modelData

    // Open panel name ("" when closed) and the bar item it opened from
    property string openPanel: ""

    function togglePanel(name: string, item: Item): void {
        if (openPanel === name) {
            openPanel = "";
            return;
        }
        panelHost.anchorItem = item;
        openPanel = name;
    }

    function closePanel(): void {
        openPanel = "";
    }

    // For opening a panel without clicking (IPC)
    function togglePanelByName(name: string): void {
        const anchors = {
            "apps": apps,
            "calendar": clock,
            "system": arch,
            "audio": speaker,
            "connectivity": connectivity,
            "display": backlight,
            "drives": drives,
            "notifications": bell
        };
        if (anchors[name])
            togglePanel(name, anchors[name]);
    }

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 7
        left: 10
        right: 10
    }
    implicitHeight: Theme.barHeight + Theme.panelGap + Theme.panelMaxHeight
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight
    color: "transparent"

    // Keyboard only while a panel is open (Esc to close, text fields)
    WlrLayershell.keyboardFocus: openPanel !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: barBackground

        Region {
            item: panelHost
        }

        Region {
            item: popups
        }
    }

    // Close when clicking outside the bar and panel
    HyprlandFocusGrab {
        windows: [root]
        active: root.openPanel !== ""
        onCleared: root.closePanel()
    }

    Item {
        id: barBackground
        width: parent.width
        height: Theme.barHeight

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.panelBackground
        }

        Row {
            anchors.left: parent.left
            height: parent.height
            spacing: 6

            Arch {
                id: arch
                active: root.openPanel === "system"
                onLeftClicked: root.togglePanel("system", this)
            }

            Workspaces {
                height: parent.height
                screen: root.screen
            }
        }

        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.openPanel === "calendar"
            onLeftClicked: root.togglePanel("calendar", this)
        }

        // Apps, drives, sound, connectivity, display, battery, notifications
        Row {
            anchors.right: parent.right
            height: parent.height
            rightPadding: 10

            Apps {
                id: apps
                active: root.openPanel === "apps"
                onLeftClicked: root.togglePanel("apps", this)
            }
            Drives {
                id: drives
                active: root.openPanel === "drives"
                onLeftClicked: root.togglePanel("drives", this)
            }
            Audio {
                id: speaker
                active: root.openPanel === "audio"
                onLeftClicked: root.togglePanel("audio", this)
            }
            Connectivity {
                id: connectivity
                active: root.openPanel === "connectivity"
                onLeftClicked: root.togglePanel("connectivity", this)
            }
            Backlight {
                id: backlight
                active: root.openPanel === "display"
                onLeftClicked: root.togglePanel("display", this)
            }
            Battery {}
            Notifications {
                id: bell
                active: root.openPanel === "notifications"
                onLeftClicked: root.togglePanel("notifications", this)
            }
        }
    }

    PanelHost {
        id: panelHost
        current: root.openPanel
        panels: ({
                "calendar": calendarPanel,
                "system": systemPanel,
                "audio": audioPanel,
                "connectivity": connectivityPanel,
                "display": displayPanel,
                "apps": appsPanel,
                "drives": drivesPanel,
                "notifications": notificationsPanel
            })
        onCloseRequested: root.closePanel()
    }

    // On the focused monitor only, and waiting while a panel is open since both drop from
    // the right
    NotificationPopups {
        id: popups
        shown: root.openPanel === "" && Hyprland.focusedMonitor?.name === root.screen.name
    }

    Component {
        id: calendarPanel

        CalendarPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: systemPanel

        SystemPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: audioPanel

        AudioPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: connectivityPanel

        ConnectivityPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: notificationsPanel

        NotificationsPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: drivesPanel

        DrivesPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: appsPanel

        AppsPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: displayPanel

        DisplayPanel {
            onCloseRequested: root.closePanel()
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.bar.modules
import qs.bar.panels
import qs.components
import qs.launcher

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

    // Right-hand icons: their own panel, or (Theme.controlCentre) the control centre at their tab.
    // The control centre anchors to the whole icon group so it doesn't shift between icons.
    readonly property var rightPanels: ["apps", "drives", "audio", "connectivity", "display", "notifications"]
    property string controlTab: "notifications"

    function openRight(name: string, item: Item): void {
        if (!Theme.controlCentre) {
            togglePanel(name, item);
            return;
        }
        if (openPanel === "control" && controlTab === name) {
            openPanel = "";
            return;
        }
        controlTab = name;
        if (openPanel !== "control") {
            panelHost.anchorItem = rightGroup;
            openPanel = "control";
        }
    }

    // Whether a right-hand icon's panel or tab is showing
    function isOpen(name: string): bool {
        return Theme.controlCentre ? openPanel === "control" && controlTab === name : openPanel === name;
    }

    // The system panel's tab, kept while the shell runs. The Arch button opens it on the last
    // tab used, Super+Esc on Power (a second Super+Esc closes it, from another tab it switches
    // to Power)
    property string systemTab: "system"

    function openSystem(tab: string, toggle: bool): void {
        if (openPanel === "system" && (toggle || systemTab === tab)) {
            openPanel = "";
            return;
        }
        systemTab = tab;
        if (openPanel !== "system") {
            panelHost.anchorItem = arch;
            openPanel = "system";
        }
    }

    // For opening a panel without clicking (IPC)
    function togglePanelByName(name: string): void {
        const anchors = {
            "apps": apps,
            "calendar": clock,
            "system": arch,
            "media": nowPlaying,
            "audio": speaker,
            "connectivity": connectivity,
            "display": backlight,
            "drives": drives,
            "notifications": bell,
            "launcher": clock,
            "screenshot": clock,
            "wallpaper": clock
        };
        if (name === "system")
            openSystem(systemTab, true);
        else if (name === "power")
            openSystem(name, false);
        else if (rightPanels.includes(name))
            openRight(name, anchors[name]);
        else if (anchors[name])
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

        Region {
            item: displayConfirm
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
                onLeftClicked: root.openSystem(root.systemTab, true)
            }

            Workspaces {
                height: parent.height
                screen: root.screen
            }

            NowPlaying {
                id: nowPlaying
                active: root.openPanel === "media"
                onLeftClicked: root.togglePanel("media", this)
            }
        }

        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.openPanel === "calendar"
            onLeftClicked: root.togglePanel("calendar", this)
        }

        // Apps, drives, sound, connectivity, display, notifications
        Row {
            id: rightGroup
            anchors.right: parent.right
            height: parent.height
            rightPadding: 10

            Apps {
                id: apps
                slotWidth: 30
                active: root.isOpen("apps")
                onLeftClicked: root.openRight("apps", this)
            }
            Drives {
                id: drives
                slotWidth: 30
                active: root.isOpen("drives")
                onLeftClicked: root.openRight("drives", this)
            }
            Audio {
                id: speaker
                slotWidth: 30
                active: root.isOpen("audio")
                onLeftClicked: root.openRight("audio", this)
            }
            Connectivity {
                id: connectivity
                slotWidth: 30
                active: root.isOpen("connectivity")
                onLeftClicked: root.openRight("connectivity", this)
            }
            Backlight {
                id: backlight
                slotWidth: 30
                active: root.isOpen("display")
                onLeftClicked: root.openRight("display", this)
            }
            Notifications {
                id: bell
                slotWidth: 30
                active: root.isOpen("notifications")
                onLeftClicked: root.openRight("notifications", this)
            }
        }
    }

    PanelHost {
        id: panelHost
        current: root.openPanel
        // The launcher's menus are only here while they're attached; the rest follow the
        // panels' setting
        attached: ["launcher", "screenshot", "wallpaper"].includes(current || shown) ? Theme.launcherAttached : Theme.panelsAttached
        panels: ({
                "calendar": calendarPanel,
                "system": systemPanel,
                "audio": audioPanel,
                "connectivity": connectivityPanel,
                "display": displayPanel,
                "apps": appsPanel,
                "drives": drivesPanel,
                "notifications": notificationsPanel,
                "control": controlPanel,
                "media": mediaPanel,
                "launcher": launcherPanel,
                "screenshot": screenshotPanel,
                "wallpaper": wallpaperPanel
            })
        onCloseRequested: root.closePanel()
    }

    // On the focused monitor only, and waiting while a panel is open since both drop from
    // the right
    NotificationPopups {
        id: popups
        shown: root.openPanel === "" && Hyprland.focusedMonitor?.name === root.screen.name
    }

    // After a display change, on every screen in case one has gone blank
    DisplayConfirm {
        id: displayConfirm
    }

    // The volume/brightness pop-up, when attached to the bar
    OsdBar {
        screenName: root.screen.name
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
            tab: root.systemTab
            onTabRequested: name => root.systemTab = name
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
        id: mediaPanel

        MediaPanel {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: controlPanel

        ControlCentrePanel {
            tab: root.controlTab
            onTabRequested: name => root.controlTab = name
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

    // With Theme.launcherAttached, hanging under the clock: Super+Space, Print and the system
    // panel's Wallpaper button
    Component {
        id: launcherPanel

        LauncherContent {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: screenshotPanel

        ScreenshotMenu {
            onCloseRequested: root.closePanel()
        }
    }

    Component {
        id: wallpaperPanel

        WallpaperPicker {
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

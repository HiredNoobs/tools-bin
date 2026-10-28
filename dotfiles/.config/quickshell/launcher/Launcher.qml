import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// The launcher's menus in the middle of the focused monitor, when Theme.launcherAttached is off:
// the app launcher (Super+Space), the screenshot menu (Print) and the wallpaper picker; and,
// always here, the keybind cheat sheet (Super+H or Super+F1). Esc or a click outside, on any
// monitor, closes it.
PanelWindow {
    id: root

    property bool open: false
    property string targetScreen: ""
    // "launcher", "screenshot", "wallpaper" or "cheatsheet"
    property string page: ""

    readonly property var pages: ({
            "launcher": launcherPage,
            "screenshot": screenshotPage,
            "wallpaper": wallpaperPage,
            "cheatsheet": cheatSheetPage
        })

    // Closes it if that menu is already open, otherwise shows it (in place of another)
    function toggle(name: string): void {
        if (open && page === name) {
            close();
            return;
        }
        targetScreen = Screens.focusedName();
        page = name;
        open = true;
    }

    function close(): void {
        open = false;
    }

    screen: Screens.byName(targetScreen)
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    // On demand rather than exclusive: Hyprland only lets the pointer reach an exclusive layer,
    // which would stop clicks on the other monitors from closing the launcher
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Clicking outside the launcher closes it
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Invisible layers over the other monitors, so clicking them closes it too
    Backdrops {
        shown: root.open
        exclude: root.targetScreen
        namespace: "quickshell-launcher-backdrop"
        onClicked: root.close()
    }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: (content.item?.implicitWidth ?? 0) + 2 * Theme.panelPadding
        height: (content.item?.implicitHeight ?? 0) + 2 * Theme.panelPadding
        radius: Theme.radius
        color: Theme.panelBackground

        // Swallow clicks so they don't reach the close area behind
        MouseArea {
            anchors.fill: parent
        }

        // Made fresh each time it opens, so it starts empty
        Loader {
            id: content
            x: Theme.panelPadding
            y: Theme.panelPadding
            active: root.open
            sourceComponent: root.pages[root.page] ?? null
        }
    }

    Component {
        id: launcherPage

        LauncherContent {
            onCloseRequested: root.close()
        }
    }

    Component {
        id: screenshotPage

        ScreenshotMenu {
            onCloseRequested: root.close()
        }
    }

    Component {
        id: wallpaperPage

        WallpaperPicker {
            onCloseRequested: root.close()
        }
    }

    Component {
        id: cheatSheetPage

        CheatSheet {
            onCloseRequested: root.close()
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Super+V's clipboard history, in a layer of its own ("quickshell-clipboard") sized to the menu,
// so Hyprland can leave it out of screen sharing (rules.lua) without hiding the bar or the
// screen. It looks like the launcher's other menus: under the clock, joined to the bar, with
// Theme.launcherAttached, otherwise floating in the middle of the screen. A click anywhere
// else, or Esc, closes it.
PanelWindow {
    id: root

    property bool open: false
    property string targetScreen: ""
    readonly property bool attached: Theme.launcherAttached
    readonly property real fillet: attached ? Theme.radius : 0

    function toggle(): void {
        if (open) {
            close();
            return;
        }
        targetScreen = Screens.focusedName();
        open = true;
    }

    function close(): void {
        open = false;
    }

    screen: Screens.byName(targetScreen)
    visible: open
    // Attached: straight under the bar (Bar.qml's top margin plus its height); floating: centred
    anchors.top: attached
    margins.top: attached ? 7 + Theme.barHeight : 0
    implicitWidth: (content.item?.implicitWidth ?? 0) + 2 * Theme.panelPadding + 2 * fillet
    implicitHeight: Math.min((content.item?.implicitHeight ?? 0) + 2 * Theme.panelPadding, Theme.panelMaxHeight)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [root]
        active: root.open
        onCleared: root.close()
    }

    PanelBackground {
        anchors.fill: parent
        attached: root.attached
    }

    Item {
        x: root.fillet
        width: parent.width - 2 * root.fillet
        height: parent.height
        clip: true
        focus: true

        Keys.onEscapePressed: root.close()

        // Made fresh each time it opens, so it starts with an empty search
        Loader {
            id: content
            x: Theme.panelPadding
            y: Theme.panelPadding
            active: root.open

            sourceComponent: ClipboardMenu {
                onCloseRequested: root.close()
            }
        }
    }
}

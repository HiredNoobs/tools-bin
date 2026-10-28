import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The on-screen display floating near the bottom of the screen, when it isn't attached to the
// bar (Theme.osdAttached; see OsdState). Clicks go through it.
PanelWindow {
    id: root

    readonly property bool shown: OsdState.shown && !Theme.osdAttached

    screen: Screens.byName(OsdState.targetScreen)
    visible: shown || pill.opacity > 0
    anchors.bottom: true
    margins.bottom: 90
    implicitWidth: pill.width
    implicitHeight: pill.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Rectangle {
        id: pill
        width: 320
        height: 56
        radius: height / 2
        color: Theme.panelBackground
        border.width: 2
        border.color: Theme.accent
        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        OsdContent {
            anchors.centerIn: parent
        }
    }
}

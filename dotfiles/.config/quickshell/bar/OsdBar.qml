import QtQuick
import qs
import qs.components
import qs.osd
import qs.services

// The on-screen display hanging under the middle of the bar, joined like the panels, when it's
// attached (Theme.osdAttached; see OsdState). Only on the screen it's for.
Item {
    id: root

    property string screenName
    readonly property bool shown: OsdState.shown && Theme.osdAttached && OsdState.targetScreen === screenName
    readonly property real fillet: Theme.radius

    x: (parent.width - width) / 2
    y: Theme.barHeight
    width: content.implicitWidth + 2 * Theme.panelPadding + 2 * fillet
    height: shown ? content.implicitHeight + 2 * Theme.panelPadding : 0
    opacity: shown ? 1 : 0
    visible: height > 0

    Behavior on height {
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.panelAnimDuration }
    }

    PanelBackground {
        anchors.fill: parent
        attached: true
    }

    OsdContent {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.panelPadding
    }
}

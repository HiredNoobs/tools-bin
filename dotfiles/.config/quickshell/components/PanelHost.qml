import QtQuick
import qs

// Drop-down panel under the bar. It grows out of the module that opened it and morphs
// in place when another module's panel is opened.
//
// With Theme.panelsAttached the panel hangs off the bar's bottom edge, joined by curved
// fillets on each side, and slides along the bar when switching modules. It has no accent
// border then, since the bar doesn't have one.
Item {
    id: root

    // Name of the open panel ("" when closed), the bar item it belongs to, and name -> Component
    property string current: ""
    property Item anchorItem: null
    property var panels: ({})

    signal closeRequested

    // Lags `current` while closing so the content fades out with the panel
    property string shown: ""
    readonly property bool open: current !== ""

    property real anchorX: 0

    readonly property bool attached: Theme.panelsAttached
    // Width of the curve joining the panel to the bar, on each side
    readonly property real fillet: attached ? Theme.radius : 0

    onCurrentChanged: {
        if (current !== "") {
            closeTimer.stop();
            shown = current;
            forceActiveFocus();
        } else {
            closeTimer.restart();
        }
    }

    // Set before `current`, so while closed the panel jumps to the new module instead of sliding
    onAnchorItemChanged: {
        if (anchorItem)
            anchorX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    }

    Behavior on anchorX {
        enabled: root.shown !== ""
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }

    Timer {
        id: closeTimer
        interval: Theme.panelAnimDuration
        onTriggered: root.shown = ""
    }

    readonly property real targetWidth: loader.item ? loader.item.implicitWidth + 2 * Theme.panelPadding : 0
    readonly property real targetHeight: loader.item ? loader.item.implicitHeight + 2 * Theme.panelPadding : 0

    // Width of the panel body, excluding the fillets
    property real bodyWidth: targetWidth

    Behavior on bodyWidth {
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }

    // Centred under the module and kept inside the bar. Attached panels also stay clear of
    // the bar's rounded ends so the fillets have a straight edge to join.
    readonly property real edgeInset: attached ? Theme.radius : 0
    x: Math.max(edgeInset, Math.min(parent.width - width - edgeInset, anchorX - width / 2))
    // Attached panels start exactly at the bar's bottom edge; any overlap draws the
    // translucent background twice and shows as a darker line
    y: Theme.barHeight + Theme.panelGap
    width: bodyWidth + 2 * fillet
    height: open ? Math.min(targetHeight, Theme.panelMaxHeight) : 0
    opacity: open ? 1 : 0
    focus: open

    Behavior on height {
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.panelAnimDuration }
    }

    Keys.onEscapePressed: closeRequested()

    PanelBackground {
        anchors.fill: parent
    }

    // Content, clipped to the body while the panel grows
    Item {
        x: root.fillet
        width: root.bodyWidth
        height: root.height
        clip: true

        Loader {
            id: loader
            x: Theme.panelPadding
            y: Theme.panelPadding
            sourceComponent: root.panels[root.shown] ?? null
            onLoaded: fadeIn.restart()
        }
    }

    // Cross-fade when the content changes
    NumberAnimation {
        id: fadeIn
        target: loader
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }
}

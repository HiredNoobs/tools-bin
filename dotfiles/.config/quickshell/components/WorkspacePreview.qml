import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services

// A live miniature of one workspace: the wallpaper with each window's live image at its real
// position, scaled down. Used by the overview and the Alt+Tab switcher.
// Call Hyprland.refreshToplevels() before showing, so window positions are current.
Rectangle {
    id: root

    property int workspaceId
    property string label: ""
    // null for a workspace that doesn't exist yet (shown empty)
    property HyprlandWorkspace workspace: null
    // The monitor it lives on, for scaling window positions
    property HyprlandMonitor monitor: null
    property bool current: false
    property bool selected: false
    property bool highlighted: false
    // Windows not matching this (title or app, case-insensitive) are dimmed
    property string filter: ""
    // Outlined, e.g. the overview's selected search match
    property HyprlandToplevel selectedWindow: null
    // Capture live frames; off when the overlay isn't showing
    property bool live: true
    // While a window is dragged over this workspace: the pointer in window (scene) coordinates.
    // dropWindow/dropSide say which window it would land next to and on which side ("l"/"r", or
    // "t"/"b" for a window taller than wide, as dwindle splits along the longer side), or, for a
    // window already on this workspace, which window it would swap with ("swap")
    property bool dragOver: false
    property point dragPoint
    property HyprlandToplevel dragged: null
    readonly property var dropHint: {
        if (!dragOver)
            return null;
        const local = mapFromItem(null, dragPoint.x, dragPoint.y);
        const inside = r => local.x >= r.x && local.x <= r.x + r.width && local.y >= r.y && local.y <= r.y + r.height;

        // Already on this workspace: swap with the window under the pointer, if it's another one
        if (dragged && (workspace?.toplevels.values ?? []).includes(dragged)) {
            const other = (workspace?.toplevels.values ?? []).find(t => t !== dragged && !t.lastIpcObject.floating && inside(windowRect(t)));
            return other ? { toplevel: other, rect: windowRect(other), side: "swap" } : null;
        }

        let best = null;
        for (const t of workspace?.toplevels.values ?? []) {
            if (t === dragged || t.lastIpcObject.floating)
                continue;
            const r = windowRect(t);
            // The window under the pointer, else the nearest one
            const distance = inside(r) ? -1 : Math.hypot(local.x - (r.x + r.width / 2), local.y - (r.y + r.height / 2));
            if (!best || distance < best.distance)
                best = { toplevel: t, rect: r, distance: distance };
        }
        if (!best)
            return null;
        const r = best.rect;
        const sideBySide = r.width >= r.height;
        return {
            toplevel: best.toplevel,
            rect: r,
            side: sideBySide ? (local.x < r.x + r.width / 2 ? "l" : "r") : (local.y < r.y + r.height / 2 ? "t" : "b")
        };
    }
    readonly property HyprlandToplevel dropWindow: dropHint?.toplevel ?? null
    readonly property string dropSide: dropHint?.side ?? ""

    // A window's rectangle in this miniature
    function windowRect(toplevel: HyprlandToplevel): rect {
        const ipc = toplevel.lastIpcObject;
        return Qt.rect(((ipc.at?.[0] ?? 0) - (monitor?.x ?? 0)) * scaleFactor, ((ipc.at?.[1] ?? 0) - (monitor?.y ?? 0)) * scaleFactor, (ipc.size?.[0] ?? 0) * scaleFactor, (ipc.size?.[1] ?? 0) * scaleFactor);
    }

    signal clicked
    signal windowClicked(HyprlandToplevel toplevel)
    // Dragging a window: position in window (scene) coordinates; dropped where released
    signal windowDragged(HyprlandToplevel toplevel, point position)
    signal windowDropped(HyprlandToplevel toplevel, point position)

    readonly property real monitorWidth: monitor ? monitor.width / monitor.scale : 1920
    readonly property real monitorHeight: monitor ? monitor.height / monitor.scale : 1080
    readonly property real scaleFactor: width / monitorWidth

    function matches(toplevel: HyprlandToplevel): bool {
        if (filter === "")
            return true;
        const ipc = toplevel.lastIpcObject;
        const text = filter.toLowerCase();
        return [toplevel.title, ipc.class, ipc.initialClass].some(part => (part ?? "").toLowerCase().includes(text));
    }

    implicitWidth: 260
    implicitHeight: width * monitorHeight / monitorWidth
    radius: 8
    color: Theme.surface
    clip: true

    Image {
        anchors.fill: parent
        source: Wallpaper.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 400
        asynchronous: true
        opacity: 0.6
    }

    // Background click: go to the workspace
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Windows, floating ones on top
    Repeater {
        model: [...(root.workspace?.toplevels.values ?? [])].sort((a, b) => (a.lastIpcObject.floating ? 1 : 0) - (b.lastIpcObject.floating ? 1 : 0))

        Item {
            id: windowItem

            required property HyprlandToplevel modelData
            readonly property var ipc: modelData.lastIpcObject
            readonly property bool matching: root.matches(modelData)

            readonly property rect area: root.windowRect(modelData)

            x: area.x
            y: area.y
            width: area.width
            height: area.height
            opacity: matching ? 1 : 0.25

            ClippingRectangle {
                anchors.fill: parent
                radius: 4
                color: Theme.panelBackground

                ScreencopyView {
                    id: capture
                    anchors.fill: parent
                    captureSource: root.live ? windowItem.modelData.wayland : null
                    live: root.live
                    constraintSize: Qt.size(parent.width * 2, parent.height * 2)
                }

                // Until the first frame arrives
                IconImage {
                    visible: !capture.hasContent && source !== ""
                    anchors.centerIn: parent
                    implicitSize: Math.min(32, parent.width / 2, parent.height / 2)
                    source: Icons.forApp(Windows.appIdOf(windowItem.modelData))
                }
            }

            // Click focuses the window; press and drag past a few pixels to move it elsewhere
            MouseArea {
                id: windowMouse

                property point pressedAt
                property bool dragging: false
                property bool dragged: false

                anchors.fill: parent
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                preventStealing: true

                onPressed: event => {
                    pressedAt = Qt.point(event.x, event.y);
                    dragging = false;
                    dragged = false;
                }
                onPositionChanged: event => {
                    if (!dragging && Math.hypot(event.x - pressedAt.x, event.y - pressedAt.y) > 8)
                        dragging = true;
                    if (dragging)
                        root.windowDragged(windowItem.modelData, mapToItem(null, event.x, event.y));
                }
                onReleased: event => {
                    if (dragging)
                        root.windowDropped(windowItem.modelData, mapToItem(null, event.x, event.y));
                    dragged = dragging;
                    dragging = false;
                }
                onClicked: {
                    if (!dragged)
                        root.windowClicked(windowItem.modelData);
                }
            }

            Rectangle {
                visible: windowItem.modelData === root.selectedWindow
                anchors.fill: parent
                anchors.margins: -2
                radius: 6
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
            }
        }
    }

    // Where a dragged window would land: the half of the window it's over, or the whole window
    // it would swap with
    Rectangle {
        readonly property rect area: root.dropHint?.rect ?? Qt.rect(0, 0, 0, 0)
        readonly property bool halfWidth: root.dropSide === "l" || root.dropSide === "r"
        readonly property bool halfHeight: root.dropSide === "t" || root.dropSide === "b"

        visible: root.dropHint !== null
        x: area.x + (root.dropSide === "r" ? area.width / 2 : 0)
        y: area.y + (root.dropSide === "b" ? area.height / 2 : 0)
        width: area.width / (halfWidth ? 2 : 1)
        height: area.height / (halfHeight ? 2 : 1)
        radius: 4
        color: Qt.alpha(Theme.accent, 0.35)
        border.width: 2
        border.color: Theme.accent
    }

    // Number in the corner
    Rectangle {
        x: 6
        y: 6
        width: number.implicitWidth + 12
        height: number.implicitHeight + 4
        radius: height / 2
        color: root.current ? Theme.accent : Qt.alpha(Theme.background, 0.8)

        PanelText {
            id: number
            anchors.centerIn: parent
            text: root.label
            color: root.current ? Theme.background : Theme.text
            font.bold: true
            font.pixelSize: Theme.panelFontSize - 2
        }
    }

    // Outline: accent when selected or a drop target, subtle for the current workspace
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.selected || root.highlighted ? 2 : root.current ? 1 : 0
        border.color: root.selected || root.highlighted ? Theme.accent : Theme.subtext
    }
}

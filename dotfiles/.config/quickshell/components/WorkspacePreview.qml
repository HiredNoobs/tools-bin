import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs

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

    signal clicked
    signal windowClicked(HyprlandToplevel toplevel)

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

    function iconFor(toplevel: HyprlandToplevel): string {
        const appId = toplevel.wayland?.appId || toplevel.lastIpcObject.class || "";
        const name = DesktopEntries.heuristicLookup(appId)?.icon || appId;
        return name.startsWith("/") ? `file://${name}` : Quickshell.iconPath(name, true);
    }

    implicitWidth: 260
    implicitHeight: width * monitorHeight / monitorWidth
    radius: 8
    color: Theme.surface
    clip: true

    Image {
        anchors.fill: parent
        source: `file://${Theme.wallpaper}`
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

            x: ((ipc.at?.[0] ?? 0) - (root.monitor?.x ?? 0)) * root.scaleFactor
            y: ((ipc.at?.[1] ?? 0) - (root.monitor?.y ?? 0)) * root.scaleFactor
            width: (ipc.size?.[0] ?? 0) * root.scaleFactor
            height: (ipc.size?.[1] ?? 0) * root.scaleFactor
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
                    source: root.iconFor(windowItem.modelData)
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.windowClicked(windowItem.modelData)
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

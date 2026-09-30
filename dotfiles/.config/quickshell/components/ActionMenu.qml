import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

// Right-click menu opened below `target`.
// items: [{ label, command } | { label, action } | { label, children: [...] } | { separator: true }]
// Entries with children expand in place when clicked.
PopupWindow {
    id: root

    required property Item target
    property var items: []
    property bool open: false

    function toggle(): void {
        open = !open;
    }

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"
    visible: open

    // Close when clicking anywhere else
    HyprlandFocusGrab {
        windows: [root]
        active: root.open
        onCleared: root.open = false
    }

    Rectangle {
        id: box
        anchors.fill: parent
        implicitWidth: 200
        implicitHeight: column.implicitHeight + 12
        radius: 6
        color: Theme.background

        Column {
            id: column
            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                model: root.items

                Column {
                    id: entry

                    required property var modelData
                    property bool expanded: false

                    width: column.width

                    Rectangle {
                        visible: entry.modelData.separator === true
                        width: parent.width
                        height: 9
                        color: "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: Qt.alpha(Theme.text, 0.3)
                        }
                    }

                    MenuRow {
                        visible: entry.modelData.separator !== true
                        label: (entry.modelData.label ?? "") + (entry.modelData.children ? (entry.expanded ? "  ▾" : "  ▸") : "")
                        onActivated: entry.modelData.children ? entry.expanded = !entry.expanded : root.run(entry.modelData)
                    }

                    Repeater {
                        model: entry.expanded ? entry.modelData.children : []

                        MenuRow {
                            required property var modelData
                            label: modelData.label
                            indent: 16
                            onActivated: root.run(modelData)
                        }
                    }
                }
            }
        }
    }

    function run(item: var): void {
        open = false;
        if (item.action)
            item.action();
        else if (item.command)
            Exec.run(item.command);
    }

    component MenuRow: Rectangle {
        id: row

        property string label
        property int indent: 0
        signal activated

        width: parent ? parent.width : 0
        height: rowText.implicitHeight + 8
        radius: 4
        color: rowMouse.containsMouse ? Qt.alpha(Theme.accent, 0.2) : "transparent"

        Text {
            id: rowText
            anchors.verticalCenter: parent.verticalCenter
            x: 8 + row.indent
            text: row.label
            color: rowMouse.containsMouse ? Theme.accent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.activated()
        }
    }
}

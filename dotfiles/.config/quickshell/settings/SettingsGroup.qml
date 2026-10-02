import QtQuick
import qs
import qs.components

// A titled card of settings rows, separated by thin lines
Column {
    id: root

    property string title: ""
    default property alias rows: card.data

    width: parent?.width ?? 0
    spacing: 8

    PanelSection {
        visible: root.title !== ""
        text: root.title
    }

    Rectangle {
        // The rows on show: not hidden ones, nor Repeaters (which take no space)
        readonly property var rows: Array.from(card.children).filter(row => row.visible && row.height > 0)

        width: parent.width
        height: card.implicitHeight
        radius: Theme.radius
        color: Theme.surface

        Column {
            id: card
            width: parent.width
        }

        // Lines between the rows
        Repeater {
            model: Math.max(0, parent.rows.length - 1)

            Rectangle {
                required property int index
                x: 16
                y: parent.rows[index + 1].y
                width: parent.width - 32
                height: 1
                color: Theme.surface
            }
        }
    }
}

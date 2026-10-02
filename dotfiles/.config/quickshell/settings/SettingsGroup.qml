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
            model: Math.max(0, card.children.length - 1)

            Rectangle {
                required property int index
                readonly property Item below: card.children[index + 1] ?? null

                visible: (card.children[index]?.visible ?? false) && (below?.visible ?? false)
                x: 16
                y: below ? below.y : 0
                width: parent.width - 32
                height: 1
                color: Theme.surface
            }
        }
    }
}

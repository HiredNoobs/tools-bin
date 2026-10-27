import QtQuick
import Quickshell
import qs

// Popup shown below `target`. Shows `text`, or any child items placed inside it.
PopupWindow {
    id: root

    required property Item target
    property string text: ""
    default property alias content: column.data

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"
    visible: true

    Rectangle {
        id: box
        anchors.fill: parent
        implicitWidth: column.implicitWidth + 16
        implicitHeight: column.implicitHeight + 12
        radius: 6
        color: Theme.background

        Column {
            id: column
            anchors.centerIn: parent

            Text {
                visible: root.text !== ""
                text: root.text
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}

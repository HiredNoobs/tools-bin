import QtQuick
import qs

// A panel section's heading (PanelSection) with controls on the right, e.g. an on/off switch
Item {
    id: root

    property alias text: title.text
    default property alias trailing: controls.data

    width: parent?.width ?? 0
    height: Math.max(title.implicitHeight, controls.implicitHeight)

    PanelSection {
        id: title
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}

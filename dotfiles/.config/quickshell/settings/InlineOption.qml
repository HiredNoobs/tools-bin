import QtQuick
import qs
import qs.components

// A label (and dim description) on the left and its control on the right, for options inside
// a SettingsBlock (a saved network's or a device's), where a SettingRow's padding is too much
Item {
    id: root

    property string label
    property string description: ""
    default property alias control: controlArea.data

    width: parent?.width ?? 0
    implicitHeight: Math.max(optionText.implicitHeight, controlArea.childrenRect.height)

    Column {
        id: optionText
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - controlArea.width - 16
        spacing: 2

        PanelText {
            width: parent.width
            text: root.label
            wrapMode: Text.WordWrap
        }

        PanelText {
            visible: text !== ""
            width: parent.width
            text: root.description
            wrapMode: Text.WordWrap
            dim: true
            font.pixelSize: Theme.panelFontSize - 1
        }
    }

    Item {
        id: controlArea
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}

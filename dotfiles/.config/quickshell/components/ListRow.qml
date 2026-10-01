import QtQuick
import Quickshell.Widgets
import qs

// Clickable row with an icon (font glyph, or image via iconSource), a label, an optional
// second line and a trailing item (e.g. a check mark or button). `selected` highlights it
// in the accent colour.
Rectangle {
    id: root

    property string icon: ""
    property string iconSource: ""
    readonly property bool hasIcon: icon !== "" || iconSource !== ""
    property string label: ""
    property string sublabel: ""
    property bool selected: false
    property bool clickable: true
    default property alias trailing: trailingArea.data
    readonly property alias hovered: mouse.containsMouse

    signal clicked

    implicitHeight: Math.max(textColumn.implicitHeight, trailingArea.childrenRect.height) + 12
    radius: 8
    color: clickable && hovered ? Theme.surfaceHover : selected ? Theme.surface : "transparent"

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    PanelText {
        id: iconText
        visible: root.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        width: 22
        text: root.icon
        color: root.selected ? Theme.accent : Theme.text
    }

    IconImage {
        visible: root.iconSource !== ""
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        implicitSize: 18
        source: root.iconSource
    }

    Column {
        id: textColumn
        anchors.verticalCenter: parent.verticalCenter
        x: root.hasIcon ? 38 : 10
        width: trailingArea.x - x - 8

        PanelText {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: root.selected ? Theme.accent : Theme.text
        }

        PanelText {
            visible: root.sublabel !== ""
            width: parent.width
            text: root.sublabel
            elide: Text.ElideRight
            dim: true
            font.pixelSize: Theme.panelFontSize - 2
        }
    }

    Item {
        id: trailingArea
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}

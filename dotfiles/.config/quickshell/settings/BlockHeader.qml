import QtQuick
import qs
import qs.components
import qs.services

// A SettingsBlock's first line: the title and a dim detail on the left, anything (buttons, a
// switch, a picker) on the right. `expandable` adds a chevron, and a click anywhere but on the
// controls opens or closes what's under it, kept in PanelState's "settings" section by
// `stateKey` for the session (see `expanded`).
Item {
    id: root

    property string title
    property string detail: ""
    property bool accent: false
    property bool expandable: false
    property string stateKey: ""
    readonly property bool expanded: expandable && PanelState.isOpen("settings", stateKey)
    default property alias trailing: trailingArea.data

    width: parent?.width ?? 0
    implicitHeight: Math.max(titleText.implicitHeight, trailingArea.implicitHeight)

    // Under the controls, so they keep their own clicks
    MouseArea {
        anchors.fill: parent
        enabled: root.expandable
        cursorShape: root.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: PanelState.toggle("settings", root.stateKey)
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - trailingArea.width - chevron.width - 16
        spacing: 8

        PanelText {
            id: titleText
            width: Math.min(implicitWidth, parent.width)
            text: root.title
            elide: Text.ElideRight
            color: root.accent ? Theme.accent : Theme.text
        }

        PanelText {
            visible: root.detail !== ""
            width: parent.width - titleText.width - parent.spacing
            text: `·  ${root.detail}`
            elide: Text.ElideRight
            dim: true
        }
    }

    Row {
        id: trailingArea
        anchors.right: chevron.left
        anchors.rightMargin: chevron.width > 0 ? 8 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }

    PanelText {
        id: chevron
        visible: root.expandable
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? 18 : 0
        horizontalAlignment: Text.AlignRight
        text: root.expanded ? "\u{F077}" : "\u{F078}"
        color: root.expanded ? Theme.accent : Theme.subtext
        font.pixelSize: Theme.panelFontSize - 3
    }
}

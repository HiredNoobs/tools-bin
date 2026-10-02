import QtQuick
import qs
import qs.components

// One setting: a label and optional description on the left, its control (a Toggle, a row of
// buttons…) on the right. Put inside a SettingsGroup. `sub` indents it under the row above (an
// option of that one); disabled (`enabled: false`) it's greyed out and ignores clicks.
// `expandable` adds a chevron, and clicking the row emits expandToggled, for rows with options
// listed under them only while open (like the panels' sections).
Item {
    id: root

    property string label: ""
    property string description: ""
    property bool sub: false
    property bool expandable: false
    property bool expanded: false
    default property alias control: controlArea.data

    signal expandToggled

    width: parent?.width ?? 0
    implicitHeight: Math.max(text.implicitHeight, controlArea.childrenRect.height) + (sub ? 20 : 28)
    opacity: enabled ? 1 : 0.4

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    // Under the control, so the control still gets its own clicks
    MouseArea {
        anchors.fill: parent
        // A disabled MouseArea still sets its cursor, so only rows that open get the hand
        enabled: root.expandable
        hoverEnabled: root.expandable
        cursorShape: root.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.expandToggled()
    }

    Column {
        id: text
        anchors.verticalCenter: parent.verticalCenter
        x: root.sub ? 40 : 16
        width: parent.width - x - 16 - controlArea.width - (controlArea.width > 0 ? 24 : 0) - chevron.width
        spacing: 3

        PanelText {
            width: parent.width
            text: root.label
            wrapMode: Text.WordWrap
            color: root.expanded ? Theme.accent : Theme.text
        }

        PanelText {
            visible: root.description !== ""
            width: parent.width
            text: root.description
            wrapMode: Text.WordWrap
            dim: true
            font.pixelSize: Theme.panelFontSize - 1
        }
    }

    Item {
        id: controlArea
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 16 + chevron.width
        width: childrenRect.width
        height: childrenRect.height
    }

    PanelText {
        id: chevron
        visible: root.expandable
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 14
        width: visible ? 30 : 0
        horizontalAlignment: Text.AlignRight
        text: root.expanded ? "\u{F077}" : "\u{F078}"
        color: root.expanded ? Theme.accent : Theme.subtext
        font.pixelSize: Theme.panelFontSize - 3
    }
}

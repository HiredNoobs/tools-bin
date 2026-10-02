import QtQuick
import Quickshell
import qs

// Row of icon tabs with a sliding underline, as at the top of the control centre and system
// panels. `tabs` is [{ name, icon, label, dot }]: label shows as a tooltip, dot marks the tab
// (e.g. unread notifications) while it isn't the current one.
Item {
    id: root

    property var tabs: []
    property string current: ""
    readonly property int currentIndex: Math.max(0, tabs.findIndex(t => t.name === current))

    signal tabRequested(string name)

    implicitHeight: tabRow.height + 4

    Row {
        id: tabRow

        Repeater {
            model: root.tabs

            MouseArea {
                id: tabButton

                required property var modelData
                readonly property bool current: modelData.name === root.current

                width: root.width / root.tabs.length
                height: 32
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.tabRequested(modelData.name)

                PanelText {
                    anchors.centerIn: parent
                    text: tabButton.modelData.icon
                    font.pixelSize: Theme.panelFontSize + 3
                    color: tabButton.current || tabButton.containsMouse ? Theme.accent : Theme.subtext

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                Rectangle {
                    visible: (tabButton.modelData.dot ?? false) && !tabButton.current
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 9
                    y: 4
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.accent
                }

                LazyLoader {
                    active: tabButton.containsMouse

                    Tooltip {
                        target: tabButton
                        text: tabButton.modelData.label
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        x: root.currentIndex * (root.width / root.tabs.length) + 12
        width: root.width / root.tabs.length - 24
        height: 2
        radius: 1
        color: Theme.accent

        Behavior on x {
            NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
        }
    }
}

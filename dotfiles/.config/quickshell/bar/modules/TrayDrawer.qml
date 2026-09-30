import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components

// Arrow that slides the system tray open, like Waybar's group/expand drawer
Row {
    id: root

    property bool expanded: false

    height: parent.height

    BarText {
        text: "\u{F104}"
        onLeftClicked: root.expanded = !root.expanded
    }

    Item {
        height: parent.height
        width: root.expanded ? content.implicitWidth : 0
        clip: true

        Behavior on width {
            NumberAnimation { duration: 600; easing.type: Easing.InOutCubic }
        }

        Row {
            id: content
            anchors.right: parent.right
            height: parent.height
            leftPadding: 5
            spacing: 10

            Repeater {
                model: SystemTray.items

                MouseArea {
                    id: trayItem

                    required property SystemTrayItem modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: event => {
                        if (event.button === Qt.LeftButton && !modelData.onlyMenu) {
                            modelData.activate();
                        } else if (modelData.hasMenu) {
                            const pos = mapToItem(null, 0, height + 6);
                            modelData.display(QsWindow.window, pos.x, pos.y);
                        }
                    }

                    IconImage {
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                    }
                }
            }

            Spacer {}
        }
    }
}

import QtQuick
import QtQuick.Controls
import Quickshell
import qs
import qs.components
import qs.services

BarText {
    id: root

    // Waybar format: %A  <calendar>  %B-%d-%Y  <clock>  %H:%M:%S %p
    text: Qt.formatDateTime(clock.date, "dddd  \u{F272}  MMMM-dd-yyyy  \u{F43A}  HH:mm:ss AP")
    leftPadding: 10
    onLeftClicked: Exec.floating("gnome-calendar", false)

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Month calendar on hover, today highlighted
    LazyLoader {
        active: root.hovered

        Tooltip {
            target: root

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "MMMM yyyy")
                color: "white"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            DayOfWeekRow {
                width: grid.width
                locale: grid.locale
                delegate: Text {
                    required property string shortName
                    text: shortName.slice(0, 2)
                    horizontalAlignment: Text.AlignHCenter
                    color: "white"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            MonthGrid {
                id: grid
                month: clock.date.getMonth()
                year: clock.date.getFullYear()
                locale: Qt.locale("en_GB")
                delegate: Text {
                    required property var model
                    text: model.day
                    horizontalAlignment: Text.AlignHCenter
                    opacity: model.month === grid.month ? 1 : 0.3
                    color: model.today ? "#fb4934" : "white"
                    font.bold: model.today
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }
    }
}

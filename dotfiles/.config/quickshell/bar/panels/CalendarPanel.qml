import QtQuick
import QtQuick.Controls
import Quickshell
import qs
import qs.components
import qs.services

// Opened from the clock: a month calendar you can page through
Column {
    id: root

    signal closeRequested

    readonly property date today: clock.date
    property int month: today.getMonth()
    property int year: today.getFullYear()
    readonly property bool showingToday: month === today.getMonth() && year === today.getFullYear()

    function shiftMonth(delta: int): void {
        const shifted = month + delta;
        year += Math.floor(shifted / 12);
        month = ((shifted % 12) + 12) % 12;
    }

    function goToToday(): void {
        month = today.getMonth();
        year = today.getFullYear();
    }

    width: 290
    spacing: 10

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PanelText {
        text: Qt.formatDate(root.today, "dddd d MMMM yyyy")
        font.bold: true
        font.pixelSize: Theme.panelFontSize + 2
    }

    // ‹  Month Year  ›
    Item {
        width: parent.width
        height: previous.implicitHeight

        PanelButton {
            id: previous
            icon: "\u{F053}"
            onClicked: root.shiftMonth(-1)
        }

        PanelText {
            anchors.centerIn: parent
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
        }

        PanelButton {
            anchors.right: parent.right
            icon: "\u{F054}"
            onClicked: root.shiftMonth(1)
        }
    }

    Column {
        width: parent.width

        DayOfWeekRow {
            width: parent.width
            locale: grid.locale
            delegate: PanelText {
                required property string shortName
                text: shortName.slice(0, 2)
                dim: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        MonthGrid {
            id: grid
            width: parent.width
            month: root.month
            year: root.year
            locale: Qt.locale("en_GB")
            spacing: 2

            delegate: Item {
                id: cell

                required property int day
                required property int month
                required property bool today

                implicitWidth: 36
                implicitHeight: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: cell.today ? Theme.accent : dayMouse.containsMouse ? Theme.surface : "transparent"
                }

                PanelText {
                    anchors.centerIn: parent
                    text: cell.day
                    opacity: cell.month === grid.month ? 1 : 0.3
                    color: cell.today ? Theme.background : Theme.text
                    font.bold: cell.today
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }

    Row {
        spacing: 8

        PanelButton {
            visible: !root.showingToday
            label: "Today"
            onClicked: root.goToToday()
        }

        PanelButton {
            label: "Open calendar"
            onClicked: {
                Exec.floating("gnome-calendar", false);
                root.closeRequested();
            }
        }
    }
}

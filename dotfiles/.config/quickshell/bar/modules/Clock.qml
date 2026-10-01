import QtQuick
import Quickshell
import qs.components

// Opens the calendar panel (wired up in Bar.qml)
BarText {
    // e.g. WEDNESDAY 30/09  •  22:48:05
    text: Qt.formatDateTime(clock.date, "dddd dd/MM  •  HH:mm:ss").toUpperCase()

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}

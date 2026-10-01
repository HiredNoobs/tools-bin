import QtQuick
import qs.components
import qs.services

// Removable drives icon, shown only while one is plugged in.
// Left click opens the drives panel (wired up in Bar.qml).
BarText {
    visible: Drives.drives.length > 0
    text: "\u{F02CA}"
}

import QtQuick
import qs

// A button naming the current choice, with a chevron, that opens a list of the choices (lit
// while it's open)
PanelButton {
    property bool open: false

    icon: open ? "\u{F077}" : "\u{F078}"
    highlighted: open
}

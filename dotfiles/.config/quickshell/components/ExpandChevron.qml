import QtQuick
import qs

// The chevron on a row that opens and shuts something under it: down while shut, up (lit)
// while open
PanelText {
    property bool expanded: false

    text: expanded ? "\u{F077}" : "\u{F078}"
    color: expanded ? Theme.accent : Theme.subtext
    font.pixelSize: Theme.panelFontSize - 3
}

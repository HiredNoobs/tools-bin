import QtQuick
import qs

// Small accent heading above a group of panel items
PanelText {
    color: Theme.accent
    font.pixelSize: Theme.panelFontSize - 2
    font.bold: true
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1
    topPadding: 4
    bottomPadding: 2
}

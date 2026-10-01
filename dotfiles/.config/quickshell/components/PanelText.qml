import QtQuick
import qs

// Standard text inside panels
Text {
    property bool dim: false

    color: dim ? Theme.subtext : Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.panelFontSize
    verticalAlignment: Text.AlignVCenter
}

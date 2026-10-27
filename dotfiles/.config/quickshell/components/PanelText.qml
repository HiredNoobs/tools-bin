import QtQuick
import qs

// Standard text inside panels. Plain text, so what apps and devices send (titles, names,
// messages) shows as it is rather than as markup; set textFormat where markup is wanted.
Text {
    property bool dim: false

    textFormat: Text.PlainText
    color: dim ? Theme.subtext : Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.panelFontSize
    verticalAlignment: Text.AlignVCenter
}

import QtQuick
import qs
import qs.components

// Hollow "|" separator, like Waybar's transparent text with a text-shadow
BarText {
    text: "|"
    hoverable: false
    color: "transparent"
    style: Text.Outline
    styleColor: Qt.alpha(Theme.text, 0.6)
}

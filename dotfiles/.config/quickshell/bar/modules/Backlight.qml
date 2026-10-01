import QtQuick
import qs.components
import qs.services

// Hidden on machines without a backlight (e.g. the desktop).
// Left click opens the display panel (wired up in Bar.qml), scroll changes brightness.
BarText {
    readonly property int percent: Math.round(Brightness.fraction * 100)
    readonly property var icons: ["\u{F00DE}", "\u{F00DF}", "\u{F00E0}"]

    visible: Brightness.available
    text: icons[Math.min(icons.length - 1, Math.floor(percent / 100 * icons.length))]
    tooltip: `Brightness ${percent}%`

    onScrolledUp: Brightness.increase()
    onScrolledDown: Brightness.decrease()
}

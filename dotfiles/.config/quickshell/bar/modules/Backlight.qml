import QtQuick
import qs.components
import qs.services

// Display icon: brightness level on machines with a backlight (laptop), a monitor elsewhere.
// Left click opens the display panel (wired up in Bar.qml); scroll changes brightness.
BarText {
    readonly property int percent: Math.round(Brightness.fraction * 100)
    readonly property var icons: ["\u{F00DE}", "\u{F00DF}", "\u{F00E0}"]

    text: Brightness.available ? icons[Math.min(icons.length - 1, Math.floor(percent / 100 * icons.length))] : "\u{F0379}"
    tooltip: Brightness.available ? `Brightness ${percent}%` : "Displays"

    onScrolledUp: {
        if (Brightness.available)
            Brightness.increase();
    }
    onScrolledDown: {
        if (Brightness.available)
            Brightness.decrease();
    }
}

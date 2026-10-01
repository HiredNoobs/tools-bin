import QtQuick
import qs
import qs.components
import qs.services

// Opens the system panel (wired up in Bar.qml). Doubles as the battery warning now the
// battery lives in that panel: amber at 30% and red at 20% while not charging.
BarText {
    text: "\u{F08C7}"
    leftPadding: 15
    restingColour: {
        if (!Battery.present || Battery.charging || Battery.plugged)
            return Theme.text;
        if (Battery.capacity <= 20)
            return Theme.critical;
        if (Battery.capacity <= 30)
            return Theme.warning;
        return Theme.text;
    }
}

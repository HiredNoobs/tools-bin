import QtQuick
import qs

// A button for something that can't be undone (forgetting a network or a device): the first
// click arms it (lit, saying `armedLabel`), and a second within `timeout` ms does it
// (`confirmed`). With `iconOnly` it shows just its icon until armed.
PanelButton {
    id: root

    property string text
    property string armedLabel: `${text}? Click again`
    property bool iconOnly: false
    property int timeout: 3000
    readonly property bool armed: disarmTimer.running

    signal confirmed

    function disarm(): void {
        disarmTimer.stop();
    }

    label: armed ? armedLabel : iconOnly ? "" : text
    highlighted: armed
    onClicked: {
        if (armed) {
            disarm();
            confirmed();
        } else {
            disarmTimer.start();
        }
    }

    Timer {
        id: disarmTimer
        interval: root.timeout
    }
}

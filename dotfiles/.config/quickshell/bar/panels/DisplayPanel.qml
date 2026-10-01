import QtQuick
import qs
import qs.components
import qs.services

// Opened from the backlight icon: brightness and nightlight
Column {
    id: root

    signal closeRequested

    width: 300
    spacing: 10

    Component.onCompleted: Nightlight.refresh()

    PanelSection {
        text: "Brightness"
    }

    Row {
        width: parent.width
        spacing: 10

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F00DE}"
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 90
            value: Brightness.fraction
            from: Brightness.minFraction
            to: 1
            onMoved: value => Brightness.set(value)
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(Brightness.fraction * 100)}%`
            dim: true
        }
    }

    PanelSection {
        text: "Nightlight"
    }

    ListRow {
        width: parent.width
        icon: "\u{F0594}"
        label: "Nightlight"
        sublabel: Nightlight.enabled ? `${Nightlight.temperature} K` : "Off"
        selected: Nightlight.enabled
        onClicked: Nightlight.setEnabled(!Nightlight.enabled)

        Toggle {
            checked: Nightlight.enabled
            onToggled: Nightlight.setEnabled(!Nightlight.enabled)
        }
    }
}

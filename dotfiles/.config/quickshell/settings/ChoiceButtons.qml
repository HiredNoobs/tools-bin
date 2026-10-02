import QtQuick
import qs.components

// A row of buttons for picking one of a few values, the current one lit. `format` turns a
// value into its label; `isEnabled` greys out values that can't be picked now.
Row {
    id: choiceButtons

    property var choices: []
    property var current
    property var format: value => `${value}`
    property var isEnabled: value => true
    signal chosen(var value)

    spacing: 6

    Repeater {
        model: choiceButtons.choices

        PanelButton {
            required property var modelData
            label: choiceButtons.format(modelData)
            highlighted: modelData === choiceButtons.current
            enabled: choiceButtons.isEnabled(modelData)
            opacity: enabled ? 1 : 0.4
            onClicked: choiceButtons.chosen(modelData)
        }
    }
}

import QtQuick
import qs.components

// A row of buttons for picking one of a few values, the current one lit. `format` turns a
// value into its label.
Row {
    id: choiceButtons

    property var choices: []
    property var current
    property var format: value => `${value}`
    signal chosen(var value)

    spacing: 6

    Repeater {
        model: choiceButtons.choices

        PanelButton {
            required property var modelData
            label: choiceButtons.format(modelData)
            highlighted: modelData === choiceButtons.current
            onClicked: choiceButtons.chosen(modelData)
        }
    }
}

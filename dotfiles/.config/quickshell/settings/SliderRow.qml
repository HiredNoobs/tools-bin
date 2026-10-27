import QtQuick
import qs
import qs.components

// A number setting on a slider, with its value shown beside it. `value` is what's saved; the
// slider follows the pointer, rounded to `step`, and `committed` hands the new value over:
// straight away, or `commitDelay` ms after it stops moving (for settings that are slow to
// apply). With `valueWidth: 0` the value isn't shown (a description can say it instead).
SettingRow {
    id: root

    property real value
    property real from: 0
    property real to: 1
    property real step: 0
    property var format: value => `${value}`
    property int commitDelay: 0
    property int sliderWidth: 220
    property int valueWidth: 70

    signal committed(real value)

    // What the slider shows: the value being dragged to, until it's saved
    property real shown: value
    onValueChanged: shown = value

    function rounded(value: real): real {
        // Whole numbers, or two decimals for fractional steps
        return step > 0 ? Number((Math.round(value / step) * step).toFixed(step < 1 ? 2 : 0)) : value;
    }

    Row {
        spacing: 10

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: root.sliderWidth
            from: root.from
            to: root.to
            value: root.shown
            onMoved: value => {
                root.shown = root.rounded(value);
                if (root.commitDelay > 0)
                    commitTimer.restart();
                else
                    root.committed(root.shown);
            }
        }

        PanelText {
            visible: root.valueWidth > 0
            anchors.verticalCenter: parent.verticalCenter
            width: root.valueWidth
            horizontalAlignment: Text.AlignRight
            text: root.format(root.shown)
            dim: true
        }
    }

    Timer {
        id: commitTimer
        interval: root.commitDelay
        onTriggered: root.committed(root.shown)
    }
}

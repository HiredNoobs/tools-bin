import QtQuick
import qs
import qs.components
import qs.services

// Print: take a screenshot of the whole screen or a selected area, now or after 2 seconds,
// saved to ~/Pictures/screenshots and opened in swappy. Up/Down or Tab move, 1-4 or Enter
// take it, Esc closes. The menu closes first and the shot waits for it to be gone.
Column {
    id: root

    signal closeRequested

    property int selected: 0

    readonly property var options: [
        { icon: "\u{F0100}", label: "Fullscreen", area: false, delay: false },
        { icon: "\u{F13AB}", label: "Fullscreen (2s delay)", area: false, delay: true },
        { icon: "\u{F05B}", label: "Select area", area: true, delay: false },
        { icon: "\u{F13AB}", label: "Select area (2s delay)", area: true, delay: true }
    ]

    function take(option): void {
        closeRequested();
        // Long enough for the menu's close animation
        const wait = option.delay ? "2" : "0.4";
        const name = `${option.area ? "snip" : "full"}-$(date +%Y%m%d-%H%M%S)-$$.png`;
        const grab = option.area ? `area=$(slurp) && grim -g "$area" "$file"` : `grim "$file"`;
        Exec.run(`dir="$HOME/Pictures/screenshots"; mkdir -p "$dir" && sleep ${wait} && file="$dir/${name}" && ${grab} && swappy -f "$file"`);
    }

    function move(delta: int): void {
        selected = (selected + delta + options.length) % options.length;
    }

    width: 300
    spacing: 4

    // After the panel host has taken focus for itself, so the keys below reach the menu
    Component.onCompleted: Qt.callLater(forceActiveFocus)

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            closeRequested();
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            move(1);
            break;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            move(-1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            take(options[selected]);
            break;
        default:
            if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + options.length) {
                take(options[event.key - Qt.Key_1]);
                break;
            }
            return;
        }
        event.accepted = true;
    }

    PanelSection {
        text: "Screenshot"
    }

    Repeater {
        model: root.options

        ListRow {
            required property var modelData
            required property int index

            width: root.width
            icon: modelData.icon
            label: modelData.label
            selected: index === root.selected
            onClicked: root.take(modelData)

            PanelText {
                text: String(index + 1)
                dim: true
            }
        }
    }
}

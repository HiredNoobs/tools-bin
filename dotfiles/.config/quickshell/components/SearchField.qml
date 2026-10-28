import QtQuick
import qs

// The search box at the top of the launcher's menus, the overview and the settings window: a
// magnifier, the text and a placeholder. Esc clears the text first, then (empty) emits
// `escaped`, which closes whatever it's in; Enter emits `accepted` (with Shift held or not).
// With `columns` set it also moves a selection through a grid of that many columns (1 for a
// list): Up/Down by a row, Tab/Backtab by one, Left/Right by one while the text is empty (they
// edit it otherwise), PageUp/PageDown by `pageRows` rows; each emits `moved`. Other keys go to
// `keyPressed` first, for anything else the box needs (accept the event to keep it).
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    // 0: no movement keys of its own
    property int columns: 0
    property int pageRows: 0
    property alias pixelSize: input.font.pixelSize
    // An accent border while typing (the overview's, on its darker background)
    property bool focusBorder: false
    readonly property alias inputFocus: input.activeFocus
    // Typing goes here when its window first shows (the settings window's)
    property alias startFocused: input.focus

    signal accepted(bool shift)
    signal escaped
    signal moved(int delta)
    signal keyPressed(var event)

    function focusInput(): void {
        input.forceActiveFocus();
    }

    function selectAll(): void {
        input.selectAll();
    }

    implicitWidth: 320
    implicitHeight: 44
    radius: 12
    color: Theme.surface
    border.width: focusBorder && input.activeFocus ? 2 : 0
    border.color: Theme.accent

    PanelText {
        anchors.verticalCenter: parent.verticalCenter
        x: 16
        text: "\u{F002}"
        dim: true
    }

    TextInput {
        id: input
        anchors.verticalCenter: parent.verticalCenter
        x: 44
        width: parent.width - 60
        color: Theme.text
        selectionColor: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        clip: true

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            dim: true
        }

        Keys.onPressed: event => {
            const grid = root.columns > 0;
            switch (event.key) {
            case Qt.Key_Escape:
                if (input.text !== "")
                    input.text = "";
                else
                    root.escaped();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.accepted((event.modifiers & Qt.ShiftModifier) !== 0);
                break;
            case Qt.Key_Up:
            case Qt.Key_Down:
                if (!grid)
                    return root.keyPressed(event);
                root.moved(event.key === Qt.Key_Up ? -root.columns : root.columns);
                break;
            case Qt.Key_Tab:
            case Qt.Key_Backtab:
                if (!grid)
                    return root.keyPressed(event);
                root.moved(event.key === Qt.Key_Backtab ? -1 : 1);
                break;
            case Qt.Key_Left:
            case Qt.Key_Right:
                // In a list, or with text to edit, they edit it
                if (!grid || root.columns === 1 || input.text !== "")
                    return root.keyPressed(event);
                root.moved(event.key === Qt.Key_Left ? -1 : 1);
                break;
            case Qt.Key_PageUp:
            case Qt.Key_PageDown:
                if (!grid || root.pageRows === 0)
                    return root.keyPressed(event);
                root.moved((event.key === Qt.Key_PageUp ? -1 : 1) * root.columns * root.pageRows);
                break;
            default:
                event.accepted = false;
                root.keyPressed(event);
                return;
            }
            event.accepted = true;
        }
    }
}

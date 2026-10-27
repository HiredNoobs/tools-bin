import QtQuick
import qs.components

// A text box for a value saved with Enter (a name, a time), showing `value` until edited.
// Enter hands over the trimmed text through `normalize` (`committed`) when it's `acceptable`
// and differs, then the box follows `value` again (left as it is if not acceptable, to fix).
// Leaving the box saves it too with `commitOnLeave`; either way, leaving it with text that
// isn't acceptable puts `value` back.
TextField {
    id: root

    property string value
    property var acceptable: text => text !== ""
    property var normalize: text => text
    property bool commitOnLeave: false
    // Typed into and not saved yet
    readonly property bool edited: text.trim() !== value

    signal committed(string value)

    function commit(): void {
        const typed = text.trim();
        if (!acceptable(typed))
            return;
        const value = normalize(typed);
        if (value !== root.value)
            committed(value);
        restore();
    }

    function restore(): void {
        text = Qt.binding(() => root.value);
    }

    text: value
    onAccepted: commit()
    onInputFocusChanged: {
        if (inputFocus)
            return;
        if (!acceptable(text.trim()))
            restore();
        else if (commitOnLeave)
            commit();
    }
}

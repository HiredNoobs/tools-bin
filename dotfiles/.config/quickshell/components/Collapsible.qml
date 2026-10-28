import QtQuick
import qs

// What a row opens, sliding open and shut under it; the panel grows and shrinks with it.
// Its content stays built while shut (use a Loader inside for heavy content).
Item {
    id: root

    property bool expanded: false
    default property alias content: holder.data

    width: parent?.width ?? 0
    height: expanded ? holder.childrenRect.height : 0
    clip: true

    Behavior on height {
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }

    Item {
        id: holder
        width: root.width
    }
}

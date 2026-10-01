import QtQuick
import qs

// Choices that slide open under a row, with a tick on the selected one. Long lists scroll
// (e.g. a monitor's 28 resolutions) and open scrolled to the selected choice.
// items: [{ label, sublabel, selected, ... }] - the whole item is passed back in `chosen`.
Item {
    id: root

    property var items: []
    property bool expanded: false
    property int maxHeight: 240

    signal chosen(var item)

    readonly property bool scrollable: rows.implicitHeight > maxHeight

    height: expanded ? Math.min(rows.implicitHeight, maxHeight) : 0
    clip: true

    // The panel grows with it
    Behavior on height {
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }

    onExpandedChanged: {
        if (!expanded || !scrollable)
            return;
        const selected = repeater.itemAt(items.findIndex(item => item.selected));
        const centred = selected ? selected.y - (maxHeight - selected.height) / 2 : 0;
        list.contentY = Math.max(0, Math.min(rows.implicitHeight - maxHeight, centred));
    }

    Flickable {
        id: list
        anchors.fill: parent
        contentHeight: rows.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.scrollable

        Column {
            id: rows
            // Room for the scrollbar
            width: list.width - (root.scrollable ? 10 : 0)
            topPadding: 4
            spacing: 2

            Repeater {
                id: repeater
                model: root.items

                ListRow {
                    id: row

                    required property var modelData

                    width: rows.width
                    label: modelData.label
                    sublabel: modelData.sublabel ?? ""
                    selected: modelData.selected ?? false
                    onClicked: {
                        root.chosen(modelData);
                        root.expanded = false;
                    }

                    PanelText {
                        visible: row.selected
                        text: "\u{F00C}"
                        color: Theme.accent
                    }
                }
            }
        }
    }

    // Scrollbar
    Rectangle {
        visible: root.scrollable
        anchors.right: parent.right
        y: list.visibleArea.yPosition * root.height
        width: 4
        height: list.visibleArea.heightRatio * root.height
        radius: 2
        color: Theme.subtext
    }
}

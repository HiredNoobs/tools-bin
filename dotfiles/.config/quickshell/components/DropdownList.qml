import QtQuick
import qs
import qs.services

// Choices that slide open under a row, with a tick on the selected one. Long lists scroll
// (e.g. a monitor's 28 resolutions) and open scrolled to the selected choice.
// items: [{ label, sublabel, iconSource, selected, ... }] - the whole item is passed back in `chosen`.
// With `stateSection` and `stateKey`, whether it's open is kept in PanelState, so it stays open
// across reopening the panel; choosing an item closes it either way, unless `closeOnChoose` is
// off (the owner then closes it, e.g. not for an item that lists more).
Item {
    id: root

    property var items: []
    property int maxHeight: 240
    property string stateSection: ""
    property string stateKey: ""
    property bool closeOnChoose: true

    property bool localExpanded: false
    readonly property bool expanded: stateSection !== "" ? PanelState.isOpen(stateSection, stateKey) : localExpanded

    function setExpanded(expanded: bool): void {
        if (stateSection === "")
            localExpanded = expanded;
        else if (expanded !== root.expanded)
            PanelState.toggle(stateSection, stateKey);
    }

    function toggle(): void {
        setExpanded(!expanded);
    }

    signal chosen(var item)

    readonly property bool scrollable: rows.implicitHeight > maxHeight

    height: expanded ? Math.min(rows.implicitHeight, maxHeight) : 0
    clip: true

    // The panel grows with it
    Behavior on height {
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }

    onExpandedChanged: scrollToSelected()
    // Opened already when created (remembered from earlier), so scroll once laid out
    Component.onCompleted: Qt.callLater(scrollToSelected)

    function scrollToSelected(): void {
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
                    iconSource: modelData.iconSource ?? ""
                    label: modelData.label
                    sublabel: modelData.sublabel ?? ""
                    selected: modelData.selected ?? false
                    onClicked: {
                        root.chosen(modelData);
                        if (root.closeOnChoose)
                            root.setExpanded(false);
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

    ScrollIndicator {
        flickable: list
        thickness: 4
        margin: 0
    }
}

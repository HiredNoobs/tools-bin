import QtQuick
import qs
import qs.components
import qs.services

// Super+V: what's been copied, newest first (see Clipboard). Type to filter; Up/Down or Tab
// move, Enter or a click copies it again (paste with Ctrl+V), Delete forgets it, Esc closes.
Item {
    id: root

    signal closeRequested

    property int selected: 0

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var results: query === "" ? Clipboard.entries : Clipboard.entries.filter(e => e.text?.toLowerCase().includes(query))

    onResultsChanged: selected = Math.min(selected, Math.max(0, results.length - 1))
    onSelectedChanged: list.positionViewAtIndex(selected, ListView.Contain)
    onQueryChanged: selected = 0

    function move(delta: int): void {
        if (results.length > 0)
            selected = Math.max(0, Math.min(results.length - 1, selected + delta));
    }

    function pick(entry): void {
        if (!entry)
            return;
        closeRequested();
        Clipboard.copy(entry);
    }

    implicitWidth: 520
    implicitHeight: body.implicitHeight

    // After the panel host has taken focus for itself, so typing goes to the search
    Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())

    Column {
        id: body
        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: clearButton.height

            PanelSection {
                anchors.verticalCenter: parent.verticalCenter
                text: "Clipboard"
            }

            PanelButton {
                id: clearButton
                anchors.right: parent.right
                visible: Clipboard.entries.length > 0
                icon: "\u{F0A7A}"
                label: "Clear"
                onClicked: Clipboard.clear()
            }
        }

        // Search
        Rectangle {
            width: parent.width
            height: 44
            radius: 12
            color: Theme.surface

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                text: "\u{F002}"
                dim: true
            }

            TextInput {
                id: search
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
                    visible: search.text === ""
                    text: "Search copied text…"
                    dim: true
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.closeRequested();
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.pick(root.results[root.selected]);
                        break;
                    case Qt.Key_Up:
                    case Qt.Key_Backtab:
                        root.move(-1);
                        break;
                    case Qt.Key_Down:
                    case Qt.Key_Tab:
                        root.move(1);
                        break;
                    case Qt.Key_Delete:
                        if (root.results[root.selected])
                            Clipboard.remove(root.results[root.selected]);
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 420)
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.results

            delegate: ListRow {
                id: row

                required property var modelData
                required property int index

                width: list.width
                selected: index === root.selected
                icon: modelData.image ? "\u{F02E9}" : "\u{F0219}"
                // The first lines, squashed onto one
                label: modelData.image ? "Picture" : modelData.text.trim().replace(/\s+/g, " ").slice(0, 200)
                onClicked: root.pick(modelData)

                Row {
                    spacing: 10

                    Image {
                        visible: !!row.modelData.image
                        width: 96
                        height: 54
                        source: row.modelData.image ? `file://${row.modelData.image}` : ""
                        sourceSize.width: 192
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    PanelText {
                        text: "\u{F0156}"
                        dim: !forget.containsMouse
                        color: forget.containsMouse ? Theme.critical : Theme.subtext

                        MouseArea {
                            id: forget
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Clipboard.remove(row.modelData)
                        }
                    }
                }
            }
        }

        PanelText {
            visible: root.results.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            bottomPadding: 8
            text: !ShellSettings.clipboardHistory ? "Clipboard history is off (Settings › Shell)" : Clipboard.entries.length === 0 ? "Nothing copied yet" : "Nothing matches"
            dim: true
        }
    }
}

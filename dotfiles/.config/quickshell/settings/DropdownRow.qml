import QtQuick
import qs
import qs.components

// A setting picked from a list that slides open under its row: a SettingRow with a
// PickerButton naming the current choice, then the list (a DropdownList), with a search box
// above it when `searchable` (the owner filters `items` by `query`). Open or not is the list's
// own: with `stateKey`, kept in PanelState's "settings" section, so it comes back after the
// shell restarts itself (the settings window closes them when it closes). Anything put inside
// shows under the list while it's open (e.g. a note that it's empty).
Column {
    id: root

    property string label
    property string description: ""
    property bool sub: false
    property bool changed: false
    property string buttonLabel
    // 0: as wide as its label
    property int buttonWidth: 240
    property var items: []
    property bool searchable: false
    property string searchPlaceholder: "Search…"
    readonly property string query: search.text.trim().toLowerCase()
    property string stateKey: ""
    property bool closeOnChoose: true
    readonly property bool open: list.expanded
    default property alias extra: under.data

    signal chosen(var item)
    signal reset

    function setOpen(open: bool): void {
        if (open) {
            search.text = "";
            if (searchable)
                Qt.callLater(search.focusInput);
        }
        list.setExpanded(open);
    }

    function focusSearch(): void {
        search.text = "";
        Qt.callLater(search.focusInput);
    }

    width: parent?.width ?? 0

    SettingRow {
        sub: root.sub
        label: root.label
        description: root.description
        changed: root.changed
        onReset: root.reset()

        PickerButton {
            width: root.buttonWidth > 0 ? root.buttonWidth : implicitWidth
            label: root.buttonLabel
            open: root.open
            onClicked: root.setOpen(!root.open)
        }
    }

    Column {
        x: 16
        width: parent.width - 32
        spacing: 6
        // Room under an open list, closing with it
        bottomPadding: Math.min(12, list.height)

        TextField {
            id: search
            visible: root.open && root.searchable
            width: parent.width
            placeholder: root.searchPlaceholder
        }

        DropdownList {
            id: list
            width: parent.width
            items: root.items
            stateSection: root.stateKey !== "" ? "settings" : ""
            stateKey: root.stateKey
            closeOnChoose: root.closeOnChoose
            onChosen: item => root.chosen(item)
        }

        Column {
            id: under
            visible: root.open
            width: parent.width
        }
    }
}

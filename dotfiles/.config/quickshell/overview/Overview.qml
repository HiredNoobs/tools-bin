import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Super+Tab: every monitor's workspaces as live miniatures (Main row, Second row), shown on the
// focused monitor. Click a workspace to go there or a window to focus it. Keyboard: arrows move
// the selection (Tab/Shift+Tab through every workspace in turn), Enter goes there, 1-9/0 jump
// within the selected row, typing searches windows
// (then the arrows step through the matches and Enter focuses the selected one), Esc closes.
PanelWindow {
    id: root

    property bool open: false
    property string targetScreen: ""
    property int selectedRow: 0
    property int selectedIndex: 0

    readonly property string filter: search.text.trim()
    // While searching: the matching windows in row and tile order, and which one is selected
    readonly property var matches: {
        if (filter === "")
            return [];
        const text = filter.toLowerCase();
        const found = [];
        for (const row of rows) {
            for (const entry of row.entries) {
                for (const t of entry.workspace?.toplevels.values ?? []) {
                    const ipc = t.lastIpcObject;
                    if ([t.title, ipc.class, ipc.initialClass].some(part => (part ?? "").toLowerCase().includes(text)))
                        found.push(t);
                }
            }
        }
        return found;
    }
    property int selectedMatch: 0
    readonly property var selectedWindow: matches[Math.min(selectedMatch, matches.length - 1)] ?? null

    onFilterChanged: selectedMatch = 0

    // [{ title, monitor, entries: [{ id, label, workspace, foreign }] }], one per monitor by role
    readonly property var rows: {
        const offsets = WorkspaceRanges.offsets;
        const monitors = Hyprland.monitors.values;
        let named = Object.entries(offsets).map(([name, offset]) => ({ name: name, offset: offset }));
        // No workspace rules: just number the monitors in order
        if (named.length === 0)
            named = monitors.map((m, index) => ({ name: m.name, offset: index * 10 }));
        named.sort((a, b) => a.offset - b.offset);

        const titles = ["Main", "Second", "Third", "Fourth"];
        const existing = Hyprland.workspaces.values.filter(ws => !ws.name.startsWith("special:"));

        return named.map(({ name, offset }) => {
            const monitor = monitors.find(m => m.name === name) ?? null;
            const own = id => id > offset && id <= offset + 10;
            const entries = [];
            for (let n = 1; n <= 10; n++) {
                const id = offset + n;
                const workspace = existing.find(ws => ws.id === id) ?? null;
                if (n <= 5 || workspace)
                    entries.push({ id: id, label: String(n), workspace: workspace, foreign: false });
            }
            // From another range but sitting here (e.g. the second screen's while it's unplugged)
            existing.filter(ws => ws.monitor === monitor && !own(ws.id)).sort((a, b) => a.id - b.id).forEach(ws => entries.push({
                id: ws.id,
                label: ws.id > 0 ? String((ws.id - 1) % 10 + 1) : ws.name,
                workspace: ws,
                foreign: true
            }));
            return { title: titles[offset / 10] ?? name, monitor: monitor, entries: entries };
        });
    }

    readonly property int maxTiles: Math.max(1, ...rows.map(row => row.entries.length))

    function toggle(): void {
        if (open)
            close();
        else
            show();
    }

    function show(): void {
        targetScreen = Hyprland.focusedMonitor?.name ?? "";
        Hyprland.refreshToplevels();
        search.text = "";
        // Start on the current workspace
        selectedRow = 0;
        selectedIndex = 0;
        const current = Hyprland.focusedWorkspace?.id;
        rows.forEach((row, r) => row.entries.forEach((entry, i) => {
            if (entry.id === current) {
                selectedRow = r;
                selectedIndex = i;
            }
        }));
        open = true;
        search.forceActiveFocus();
    }

    function close(): void {
        open = false;
    }

    function goToWorkspace(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
        close();
    }

    function focusWindow(toplevel: HyprlandToplevel): void {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${toplevel.address}" })`);
        close();
    }

    function moveSelection(dRow: int, dIndex: int): void {
        // While searching, any arrow steps through the matching windows
        if (filter !== "") {
            if (matches.length > 0)
                selectedMatch = (selectedMatch + (dRow + dIndex) + matches.length) % matches.length;
            return;
        }
        selectedRow = Math.max(0, Math.min(rows.length - 1, selectedRow + dRow));
        const count = rows[selectedRow].entries.length;
        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + dIndex));
    }

    // Tab / Shift+Tab: the next or previous workspace across all rows, wrapping round; while
    // searching, the next or previous matching window
    function cycle(step: int): void {
        if (filter !== "") {
            moveSelection(0, step);
            return;
        }
        const flat = [];
        rows.forEach((row, r) => row.entries.forEach((_, i) => flat.push([r, i])));
        const position = flat.findIndex(([r, i]) => r === selectedRow && i === selectedIndex);
        [selectedRow, selectedIndex] = flat[(position + step + flat.length) % flat.length];
    }

    // Enter: the selected matching window while searching, otherwise the selected workspace
    function activate(): void {
        if (filter !== "") {
            if (selectedWindow)
                focusWindow(selectedWindow);
            return;
        }
        const entry = rows[selectedRow]?.entries[selectedIndex];
        if (entry)
            goToWorkspace(entry.id);
    }

    screen: Quickshell.screens.find(s => s.name === targetScreen) ?? Quickshell.screens[0]
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Backdrop; clicking it closes
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.background, 0.88)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 18

        readonly property real tileWidth: Math.min(280, (root.width - 160 - (root.maxTiles - 1) * 14) / root.maxTiles)

        // Search
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: 40
            radius: 20
            color: Theme.panelBackground
            border.width: search.activeFocus ? 2 : 0
            border.color: Theme.accent

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                text: "\u{F002}"
                dim: true
            }

            TextInput {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                x: 42
                width: parent.width - 58
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search windows…"
                    dim: true
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.close();
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.activate();
                        break;
                    case Qt.Key_Left:
                        root.moveSelection(0, -1);
                        break;
                    case Qt.Key_Right:
                        root.moveSelection(0, 1);
                        break;
                    case Qt.Key_Up:
                        root.moveSelection(-1, 0);
                        break;
                    case Qt.Key_Down:
                        root.moveSelection(1, 0);
                        break;
                    case Qt.Key_Tab:
                        root.cycle(1);
                        break;
                    case Qt.Key_Backtab:
                        root.cycle(-1);
                        break;
                    default:
                        // Number keys jump within the selected row, unless typing a search
                        if (search.text === "" && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                            const n = event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0;
                            const row = root.rows[root.selectedRow];
                            const entry = row?.entries.find(e => !e.foreign && e.label === String(n));
                            root.goToWorkspace(entry ? entry.id : (row ? row.entries[0].id - 1 + n : n));
                            break;
                        }
                        return;
                    }
                    event.accepted = true;
                }
            }
        }

        Repeater {
            model: root.rows

            Column {
                id: rowColumn

                required property var modelData
                required property int index

                spacing: 8

                PanelSection {
                    text: rowColumn.modelData.title
                }

                Row {
                    spacing: 14

                    Repeater {
                        model: rowColumn.modelData.entries

                        Row {
                            id: tile

                            required property var modelData
                            required property int index

                            spacing: 14

                            // Before the first workspace from another range
                            Rectangle {
                                visible: tile.modelData.foreign && (tile.index === 0 || !rowColumn.modelData.entries[tile.index - 1].foreign)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: preview.height * 0.6
                                radius: 1
                                color: Theme.subtext
                            }

                            WorkspacePreview {
                                id: preview
                                width: content.tileWidth
                                workspaceId: tile.modelData.id
                                label: tile.modelData.label
                                workspace: tile.modelData.workspace
                                monitor: rowColumn.modelData.monitor
                                current: Hyprland.focusedWorkspace?.id === tile.modelData.id
                                selected: root.filter === "" && root.selectedRow === rowColumn.index && root.selectedIndex === tile.index
                                filter: root.filter
                                selectedWindow: root.selectedWindow
                                live: root.open
                                onClicked: root.goToWorkspace(tile.modelData.id)
                                onWindowClicked: toplevel => root.focusWindow(toplevel)
                            }
                        }
                    }
                }
            }
        }
    }
}

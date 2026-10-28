import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Alt+Tab: hold Alt and tap Tab (Shift+Tab back) to step through workspaces with windows, both
// monitors, most recently used first; release Alt to go to the selected one. A quick tap goes
// straight to the previous workspace without showing anything; holding shows a strip of live
// miniatures. Esc cancels, Enter or a click goes there now.
//
// Driven by Hyprland binds (hypr/hyprland/keybinds.lua) over IPC. Each hold of Alt is one session,
// numbered by Hyprland: step(session, ±1) for each Tab and commit(session) when Alt is released.
// They arrive as separate commands, so a quick tap's commit can overtake its step; a commit for
// a session that hasn't started yet waits for it.
PanelWindow {
    id: root

    property int session: -1
    property bool active: false
    property int pendingCommit: -1
    property string targetScreen: ""
    // Snapshot taken when the session starts: [{ id, title, number, workspace }]
    property var entries: []
    property int selected: 0

    function step(id: int, delta: int): void {
        // A new hold of Alt, or the same number again after a session ended without Hyprland
        // seeing Alt released (the switcher saw it instead)
        if (id !== session || !active)
            begin(id);
        if (entries.length > 1)
            selected = (selected + delta + entries.length) % entries.length;
        if (pendingCommit === id) {
            pendingCommit = -1;
            commit(id);
        }
    }

    function commit(id: int): void {
        if (id !== session || !active) {
            pendingCommit = id;
            return;
        }
        go(entries[selected]?.id);
    }

    function cancel(): void {
        finish();
    }

    function begin(id: int): void {
        session = id;
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        targetScreen = Screens.focusedName();
        entries = collect();
        selected = 0;
        active = true;
        showTimer.restart();
    }

    function go(id): void {
        finish();
        if (id === undefined || id === Hyprland.focusedWorkspace?.id)
            return;
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${Exec.workspace(id)} })`);
        // Straight away, so another Alt+Tab right after comes back here
        WorkspaceHistory.record(id);
    }

    function finish(): void {
        active = false;
        showTimer.stop();
    }

    // The current workspace first, then the others with windows, most recently used first
    function collect(): var {
        const current = Hyprland.focusedWorkspace;
        const usable = Hyprland.workspaces.values.filter(ws => !ws.name.startsWith("special:") && (ws === current || ws.toplevels.values.length > 0));
        const rank = ws => {
            if (ws === current)
                return -1;
            const index = WorkspaceHistory.order.indexOf(ws.id);
            return index === -1 ? 1000 + ws.id : index;
        };
        return usable.sort((a, b) => rank(a) - rank(b)).map(ws => describe(ws));
    }

    // "Main 3", "Second 2", or the name of a named workspace ("Games")
    function describe(ws: HyprlandWorkspace): var {
        if (ws.id < 1)
            return { id: ws.id, title: ws.name.charAt(0).toUpperCase() + ws.name.slice(1), number: "", workspace: ws };
        const ranged = Object.keys(WorkspaceRanges.offsets).length > 0;
        const number = ranged ? WorkspaceRanges.numberOf(ws.id) : String(ws.id);
        const title = ranged ? (WorkspaceRanges.titleOf(ws.id) || "Workspace") : "Workspace";
        return { id: ws.id, title: `${title} ${number}`, number: number, workspace: ws };
    }

    // Shown only when Alt is held a moment, so a quick tap doesn't flash
    Timer {
        id: showTimer
        interval: 150
    }

    readonly property bool shown: active && !showTimer.running

    screen: Screens.byName(targetScreen)
    visible: shown
    implicitWidth: card.width
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-switcher"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown)
            keys.forceActiveFocus();
    }

    Rectangle {
        id: card

        readonly property int gap: 14
        readonly property real tileWidth: Math.min(240, ((root.screen?.width ?? 1920) * 0.9 - 2 * Theme.panelPadding - (root.entries.length - 1) * gap) / Math.max(1, root.entries.length))

        width: strip.implicitWidth + 2 * Theme.panelPadding
        height: strip.implicitHeight + 2 * Theme.panelPadding
        radius: Theme.radius
        color: Theme.panelBackground
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.5)

        // Keys while it has the keyboard; Tab itself goes to the Hyprland binds
        Item {
            id: keys
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.cancel();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.go(root.entries[root.selected]?.id);
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Left) {
                    const delta = event.key === Qt.Key_Right ? 1 : -1;
                    root.selected = (root.selected + delta + root.entries.length) % root.entries.length;
                } else {
                    return;
                }
                event.accepted = true;
            }
            // Backup for Hyprland's release bind
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Alt && root.active)
                    root.commit(root.session);
            }
        }

        Row {
            id: strip
            x: Theme.panelPadding
            y: Theme.panelPadding
            spacing: card.gap

            Repeater {
                model: root.entries

                Column {
                    id: entry

                    required property var modelData
                    required property int index

                    spacing: 6

                    WorkspacePreview {
                        width: card.tileWidth
                        workspaceId: entry.modelData.id
                        label: entry.modelData.number
                        workspace: entry.modelData.workspace
                        monitor: entry.modelData.workspace.monitor
                        current: entry.index === 0
                        selected: entry.index === root.selected
                        live: root.shown
                        onClicked: root.go(entry.modelData.id)
                        onWindowClicked: root.go(entry.modelData.id)
                    }

                    PanelText {
                        width: card.tileWidth
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: entry.modelData.title
                        color: entry.index === root.selected ? Theme.accent : Theme.subtext
                        font.bold: entry.index === root.selected
                    }
                }
            }
        }
    }
}

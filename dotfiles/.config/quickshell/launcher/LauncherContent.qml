import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// The app launcher's search box and results, shown in the centred popup (Launcher) or as a
// panel attached to the bar (Theme.launcherAttached).
// Type to search the installed apps (name first, then generic name, keywords and command); the
// apps used most and most recently come first. Words matching an app's desktop action (e.g.
// "private" for Firefox's New Private Window) list that action too. Arrows or Tab/Shift+Tab move
// the selection, Enter or a click starts it, Esc closes.
//
// Prefixes switch mode: `=` calculates with qalc (units and currencies too; Enter copies the
// answer), `>` runs a shell command in a floating terminal that stays open (Shift+Enter runs it
// in the background).
Item {
    id: root

    signal closeRequested

    property int selected: 0
    // Where the pointer was last seen over the grid, to tell real movement from the enter event
    // a still pointer gets when the launcher opens under it
    property point lastPointer: Qt.point(-1, -1)

    readonly property int columns: 2
    readonly property int visibleRows: 8
    readonly property int cellHeight: 46

    // Every app that shows in menus, by name
    readonly property var apps: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property string mode: search.text.startsWith("=") ? "calc" : search.text.startsWith(">") ? "run" : "apps"
    // The text after the mode's prefix
    readonly property string input: (mode === "apps" ? search.text : search.text.slice(1)).trim()
    readonly property string query: mode === "apps" ? input.toLowerCase() : ""

    // [{ app, action }]: action is null for the app itself
    readonly property var results: {
        if (mode !== "apps")
            return [];
        if (query === "") {
            return apps
                .map(app => ({ app: app, action: null, score: AppUsage.score(app.id) }))
                .sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));
        }
        const words = query.split(/\s+/);
        const found = [];
        for (const app of apps) {
            const usage = Math.min(15, AppUsage.score(app.id));
            const appScore = score(app, words);
            if (appScore > 0)
                found.push({ app: app, action: null, score: appScore + usage });
            for (const action of app.actions) {
                const actionScore = scoreAction(app, action, words);
                if (actionScore > 0)
                    found.push({ app: app, action: action, score: actionScore + usage });
            }
        }
        return found.sort((a, b) => b.score - a.score || label(a).localeCompare(label(b)));
    }

    onResultsChanged: selected = 0
    onSelectedChanged: grid.positionViewAtIndex(selected, GridView.Contain)

    function label(result): string {
        return result.action ? `${result.app.name}: ${result.action.name}` : result.app.name;
    }

    // How well one word matches a name: at its start, at the start of a word in it, anywhere in
    // it, or (barely) as letters in order
    function nameMatch(word: string, name: string): int {
        if (name.startsWith(word))
            return 100;
        if (name.split(/[\s\-_.]+/).some(part => part.startsWith(word)))
            return 80;
        if (name.includes(word))
            return 60;
        if (isSubsequence(word, name))
            return 10;
        return 0;
    }

    function wordScore(app, word: string): int {
        const others = [app.genericName, ...app.keywords, (app.command[0] ?? "").split("/").pop()]
            .map(text => (text ?? "").toLowerCase());
        // Letters in order only count for the name
        const name = nameMatch(word, app.name.toLowerCase());
        if (name > 10)
            return name;
        if (others.some(text => text.startsWith(word)))
            return 50;
        if (others.some(text => text.includes(word)))
            return 30;
        return name;
    }

    // Every word has to match somewhere; matches in the name count most, at its start most of all
    function score(app, words: var): int {
        let total = 0;
        for (const word of words) {
            const best = wordScore(app, word);
            if (best === 0)
                return 0;
            total += best;
        }
        return total;
    }

    // Like an app, but at least one word has to be in the action's name (so typing an app's name
    // alone doesn't list all its actions), and the rest can match the app
    function scoreAction(app, action, words: var): int {
        const name = action.name.toLowerCase();
        let total = 0;
        let named = false;
        for (const word of words) {
            // From 3 letters, so a letter or two doesn't list every app's actions
            const inAction = word.length >= 3 && name.split(/\s+/).some(part => part.startsWith(word)) ? 70 : 0;
            const best = Math.max(inAction, wordScore(app, word));
            if (best === 0)
                return 0;
            named = named || inAction > 0;
            total += best;
        }
        return named ? total : 0;
    }

    // The letters of `word` appear in `text` in order from its start, e.g. "ffx" in "firefox"
    function isSubsequence(word: string, text: string): bool {
        if (word[0] !== text[0])
            return false;
        let i = 0;
        for (const c of text) {
            if (c === word[i])
                i++;
            if (i === word.length)
                return true;
        }
        return false;
    }

    // Called each time it opens: empty search, first app selected, typing goes to the search
    function reset(): void {
        search.text = "";
        selected = 0;
        lastPointer = Qt.point(-1, -1);
        search.forceActiveFocus();
    }

    function move(delta: int): void {
        if (results.length > 0)
            selected = Math.max(0, Math.min(results.length - 1, selected + delta));
    }

    // Enter: what the current mode does with the input (Shift+Enter: `>` runs in the background)
    function accept(shift: bool): void {
        if (mode === "calc") {
            // Still working out the latest input: copied once that's done, not the last answer
            if (calculator.answerFor !== calculator.wanted) {
                calculator.acceptWhenReady = true;
                return;
            }
            if (calculator.answer === "")
                return;
            root.closeRequested();
            Clipboard.copy({ text: calculator.answer });
        } else if (mode === "run") {
            if (input === "")
                return;
            root.closeRequested();
            if (shift)
                Exec.viaHyprland(input, "");
            else
                Exec.floating(`kitty --hold sh -c ${Exec.quote(input)}`, true);
        } else {
            launch(results[selected]);
        }
    }

    function launch(result): void {
        if (!result)
            return;
        root.closeRequested();
        AppUsage.record(result.app.id);
        launchCommand(result.app, result.action?.command ?? result.app.command);
    }

    function launchCommand(app, args: var): void {
        let command = args.map(arg => Exec.quote(arg)).join(" ");
        if (app.runInTerminal)
            command = `kitty ${command}`;
        if (app.workingDirectory !== "")
            command = `cd ${Exec.quote(app.workingDirectory)} && ${command}`;
        Exec.viaHyprland(command, "");
    }

    // `=`: the answer for the latest input, recalculated as it changes (one qalc at a time; when
    // it finishes, it runs again if the input moved on meanwhile)
    QtObject {
        id: calculator

        property string answer: ""
        // The input `answer` is for, and whether Enter came before it was ready
        property string answerFor: ""
        property bool acceptWhenReady: false
        readonly property string wanted: root.mode === "calc" ? root.input : ""

        onWantedChanged: {
            acceptWhenReady = false;
            if (wanted === "") {
                answer = "";
                answerFor = "";
            }
            else if (!qalc.running)
                qalc.calculate();
        }
    }

    Process {
        id: qalc

        property string expression: ""

        function calculate(): void {
            expression = calculator.wanted;
            command = ["qalc", "-t", "--", expression];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (qalc.expression === calculator.wanted) {
                    calculator.answer = text.trim();
                    calculator.answerFor = qalc.expression;
                    if (calculator.acceptWhenReady) {
                        calculator.acceptWhenReady = false;
                        root.accept(false);
                    }
                }
            }
        }
        onExited: {
            if (calculator.wanted !== "" && expression !== calculator.wanted)
                calculate();
        }
    }

    implicitWidth: 612
    // After the panel host has taken focus for itself
    Component.onCompleted: Qt.callLater(reset)
    implicitHeight: body.implicitHeight

    Column {
        id: body
        width: parent.width
        spacing: 10


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
                    text: "Search apps…"
                    dim: true
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.closeRequested();
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.accept((event.modifiers & Qt.ShiftModifier) !== 0);
                        break;
                    case Qt.Key_Up:
                        root.move(-root.columns);
                        break;
                    case Qt.Key_Down:
                        root.move(root.columns);
                        break;
                    case Qt.Key_Left:
                        // Left/Right edit the search text unless it's empty
                        if (search.text !== "")
                            return;
                        root.move(-1);
                        break;
                    case Qt.Key_Right:
                        if (search.text !== "")
                            return;
                        root.move(1);
                        break;
                    case Qt.Key_Tab:
                        root.move(1);
                        break;
                    case Qt.Key_Backtab:
                        root.move(-1);
                        break;
                    case Qt.Key_PageUp:
                        root.move(-root.columns * root.visibleRows);
                        break;
                    case Qt.Key_PageDown:
                        root.move(root.columns * root.visibleRows);
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }
        }

        GridView {
            id: grid
            visible: root.mode === "apps"
            width: parent.width
            height: root.visibleRows * root.cellHeight
            cellWidth: width / root.columns
            cellHeight: root.cellHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.results

            PanelText {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: "No matching apps"
                dim: true
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool isSelected: index === root.selected

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 12
                    color: cell.isSelected ? Theme.surfaceHover : "transparent"

                    IconImage {
                        id: icon
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        implicitSize: 32
                        source: Quickshell.iconPath(cell.modelData.action?.icon || cell.modelData.app.icon, "application-x-executable")
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: icon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        text: root.label(cell.modelData)
                        color: cell.isSelected ? Theme.accent : Theme.text
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Hover selects, but only when the pointer actually moves, so
                    // the selection doesn't jump to whatever sits under a still pointer
                    onPositionChanged: mouse => {
                        const point = mapToItem(null, mouse.x, mouse.y);
                        const moved = root.lastPointer.x >= 0 && (point.x !== root.lastPointer.x || point.y !== root.lastPointer.y);
                        root.lastPointer = point;
                        if (moved)
                            root.selected = cell.index;
                    }
                    onClicked: root.launch(cell.modelData)
                }
            }
        }

        // `=` and `>`: one row with the answer or the command, in the grid's place
        Item {
            visible: root.mode !== "apps"
            width: parent.width
            height: grid.height

            Rectangle {
                id: modeRow
                width: parent.width
                height: root.cellHeight
                radius: 12
                color: rowMouse.containsMouse ? Theme.surfaceHover : Theme.surface

                PanelText {
                    id: modeIcon
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    width: 24
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 20
                    // Calculator, console
                    text: root.mode === "calc" ? "\u{F00EC}" : "\u{F018D}"
                    color: Theme.accent
                }

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: modeIcon.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSize
                    dim: root.input === ""
                    text: {
                        if (root.mode === "calc")
                            return root.input === "" ? "Type a calculation, e.g. 100 usd to gbp" : `= ${calculator.answer}`;
                        return root.input === "" ? "Type a command to run" : root.input;
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.accept(false)
                }
            }

            PanelText {
                anchors.top: modeRow.bottom
                anchors.topMargin: 8
                x: 14
                dim: true
                text: root.mode === "calc" ? "Enter copies the answer" : "Enter runs it in a terminal    Shift+Enter runs it in the background"
            }
        }
    }
}

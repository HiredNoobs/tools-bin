import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Super+F1: every Hyprland bind that has a description, read live from `hyprctl binds -j`
// and grouped under the section headers of keybinds.lua. Binds sharing a description become one
// entry (Super + ← / H), and the workspace number binds one "1–0" entry. Typing filters by
// description or key, Esc clears the search and then closes.
Item {
    id: root

    signal closeRequested

    readonly property string keybindsFile: Quickshell.env("HOME") + "/.config/hypr/hyprland/keybinds.lua"
    readonly property int columns: 3
    readonly property int columnWidth: 380
    readonly property int columnGap: 24
    readonly property int maxListHeight: 640

    property var binds: []
    // Description -> { section header, position }, from keybinds.lua
    property var sectionOf: ({})
    // [{ name, entries: [{ description, combos: [{ mods: [], keys: [] }] }] }]
    readonly property var sections: buildSections(binds, sectionOf)
    readonly property var shown: filterSections(sections, search.text.trim().toLowerCase())
    // The shown sections dealt into columns, each going to the shortest so far
    readonly property var columnSections: {
        const columns = Array.from({ length: root.columns }, () => ({ rows: 0, sections: [] }));
        for (const section of shown) {
            const shortest = columns.reduce((a, b) => (b.rows < a.rows ? b : a));
            shortest.sections.push(section);
            shortest.rows += section.entries.length + 2;
        }
        return columns.map(column => column.sections);
    }

    readonly property var keyNames: ({
            "LEFT": "←",
            "RIGHT": "→",
            "UP": "↑",
            "DOWN": "↓",
            "RETURN": "Enter",
            "ESCAPE": "Esc",
            "SPACE": "Space",
            "TAB": "Tab",
            "PRINT": "Print",
            "mouse:272": "Left click",
            "mouse:273": "Right click",
            "mouse:274": "Middle click"
        })

    function keyName(key: string): string {
        if (keyNames[key])
            return keyNames[key];
        if (key.startsWith("XF86"))
            return key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        return key.length === 1 ? key.toUpperCase() : key.charAt(0) + key.slice(1).toLowerCase();
    }

    function modNames(mask: int): var {
        const names = [];
        if (mask & 64)
            names.push("Super");
        if (mask & 4)
            names.push("Ctrl");
        if (mask & 8)
            names.push("Alt");
        if (mask & 1)
            names.push("Shift");
        return names;
    }

    // Section headers are a "-- Name" line between two lines of dashes; every description below
    // one belongs to it
    function parseSections(text: string): var {
        const lines = text.split("\n");
        const sectionOf = {};
        let section = "Other";
        let position = 0;
        for (let i = 0; i < lines.length; i++) {
            const header = lines[i].match(/^--\s+(\S.*)$/);
            if (header && /^-{10,}$/.test(lines[i - 1] ?? "") && /^-{10,}$/.test(lines[i + 1] ?? "")) {
                section = header[1].trim();
                continue;
            }
            const pattern = /description\s*=\s*"([^"]+)"/g;
            let match;
            while ((match = pattern.exec(lines[i])) !== null) {
                if (!(match[1] in sectionOf))
                    sectionOf[match[1]] = { section: section, position: position++ };
            }
        }
        return sectionOf;
    }

    function buildSections(binds: var, sectionOf: var): var {
        const sections = [];
        const entries = {};
        for (const bind of binds) {
            if (!bind.has_description || bind.submap !== "")
                continue;
            // Keypad digits repeat the number row
            if (/^KP_\d$/.test(bind.key))
                continue;
            const description = bind.description;
            let entry = entries[description];
            if (!entry) {
                const name = sectionOf[description]?.section ?? "Other";
                let section = sections.find(s => s.name === name);
                if (!section) {
                    section = { name: name, entries: [] };
                    sections.push(section);
                }
                entry = { description: description, combos: [] };
                entries[description] = entry;
                section.entries.push(entry);
            }
            const mods = modNames(bind.modmask);
            const key = /^\d$/.test(bind.key) ? "1–0" : keyName(bind.key);
            // Combos with the same modifiers share them: Super + ← / H
            const combo = entry.combos.find(c => c.mods.join() === mods.join());
            if (!combo)
                entry.combos.push({ mods: mods, keys: [key] });
            else if (!combo.keys.includes(key))
                combo.keys.push(key);
        }
        // In the order of keybinds.lua (hyprctl lists them in its own order), binds from
        // elsewhere ("Other") last
        const position = description => sectionOf[description]?.position ?? Infinity;
        for (const section of sections)
            section.entries.sort((a, b) => position(a.description) - position(b.description));
        return sections.sort((a, b) => position(a.entries[0].description) - position(b.entries[0].description));
    }

    function comboText(combo: var): string {
        return [...combo.mods, ...combo.keys].join(" ");
    }

    function filterSections(sections: var, query: string): var {
        if (query === "")
            return sections;
        return sections.map(section => ({
                    name: section.name,
                    entries: section.entries.filter(entry => entry.description.toLowerCase().includes(query)
                        || section.name.toLowerCase().includes(query)
                        || entry.combos.some(combo => comboText(combo).toLowerCase().includes(query)))
                })).filter(section => section.entries.length > 0);
    }

    implicitWidth: columns * columnWidth + (columns - 1) * columnGap
    implicitHeight: header.height + 14 + Math.min(list.contentHeight, maxListHeight)

    Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())

    Process {
        command: ["hyprctl", "binds", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text);
                } catch (e) {
                    root.binds = [];
                }
            }
        }
    }

    Process {
        command: ["cat", root.keybindsFile]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.sectionOf = root.parseSections(text)
        }
    }

    Item {
        id: header
        width: parent.width
        height: 38

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F030C}  Keybinds"
            font.pixelSize: Theme.fontSize + 2
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 320
            height: parent.height
            radius: Theme.radius
            color: Theme.surface

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                text: "\u{F0349}"
                dim: true
            }

            TextInput {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                x: 40
                width: parent.width - 54
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search keybinds…"
                    dim: true
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        if (search.text !== "")
                            search.text = "";
                        else
                            root.closeRequested();
                        break;
                    case Qt.Key_Down:
                        list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + 60);
                        break;
                    case Qt.Key_Up:
                        list.contentY = Math.max(0, list.contentY - 60);
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }
        }
    }

    Flickable {
        id: list
        y: header.height + 14
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        contentHeight: columnsRow.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
            id: columnsRow
            spacing: root.columnGap

            Repeater {
                model: root.columnSections

                Column {
                    id: column

                    required property var modelData
                    width: root.columnWidth
                    spacing: 14

                    Repeater {
                        model: column.modelData

                        Column {
                            id: section

                            required property var modelData
                            width: root.columnWidth
                            spacing: 6

                            PanelSection {
                                text: section.modelData.name
                            }

                            Repeater {
                                model: section.modelData.entries

                                Item {
                                    id: entry

                                    required property var modelData
                                    width: root.columnWidth
                                    height: Math.max(descriptionText.implicitHeight, combos.implicitHeight)

                                    PanelText {
                                        id: descriptionText
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - combos.implicitWidth - 12
                                        text: entry.modelData.description
                                        wrapMode: Text.WordWrap
                                    }

                                    Column {
                                        id: combos
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        Repeater {
                                            model: entry.modelData.combos

                                            // Modifier caps, then the keys separated by "/"
                                            Row {
                                                id: combo

                                                required property var modelData
                                                anchors.right: parent.right
                                                spacing: 3

                                                Repeater {
                                                    model: combo.modelData.mods

                                                    KeyCap {
                                                        required property string modelData
                                                        text: modelData
                                                        dim: true
                                                    }
                                                }

                                                Repeater {
                                                    model: combo.modelData.keys

                                                    Row {
                                                        required property string modelData
                                                        required property int index
                                                        spacing: 3

                                                        PanelText {
                                                            visible: parent.index > 0
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: "/"
                                                            dim: true
                                                        }

                                                        KeyCap {
                                                            text: parent.modelData
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PanelText {
        visible: root.binds.length > 0 && root.shown.length === 0
        y: header.height + 24
        text: "No keybinds match"
        dim: true
    }

    component KeyCap: Rectangle {
        property alias text: label.text
        property bool dim: false

        width: label.implicitWidth + 12
        height: label.implicitHeight + 6
        radius: 5
        color: dim ? "transparent" : Theme.surface
        border.width: 1
        border.color: Theme.surface

        PanelText {
            id: label
            anchors.centerIn: parent
            font.pixelSize: Theme.panelFontSize - 2
            dim: parent.dim
        }
    }
}

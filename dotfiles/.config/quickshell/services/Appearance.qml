pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Look and feel for Settings › Appearance, in place of nwg-look, qt6ct and Kvantum Manager.
// One set of choices goes to every toolkit, in the same places those tools write (so they
// keep working):
// - GTK 4 / libadwaita: gsettings org.gnome.desktop.interface
// - GTK 3 and 4: ~/.config/gtk-3.0/settings.ini, ~/.config/gtk-4.0/settings.ini
// - Qt: ~/.config/qt6ct/qt6ct.conf (icons, fonts, file chooser), ~/.config/Kvantum (style)
// - Hyprland's cursor: `hyprctl setcursor` now, and ~/.config/hypr/appearance.lua (loaded by
//   hyprland.lua, this machine's own) for the next login
// - The shell's own icons: QS_ICON_THEME, in appearance.lua and Hyprland's environment, read
//   when the shell starts, so it restarts (through Hyprland) when the icons change
// Only the widget style is separate per toolkit (a GTK theme, a Kvantum theme), and Qt can
// have its own font, as Qt and GTK size fonts differently. Each setting's value from before
// its first change is kept (in Quickshell's state folder) for the settings window's ↺, and
// forgotten once it's back to that value; a font's or cursor's size is a setting of its own.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`

    // Current choices, read from gsettings (and Qt's own files for the Qt-only ones)
    property bool dark: true
    property string gtkTheme: ""
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property string font: ""
    property int fontSize: 11
    property string monoFont: ""
    property int monoSize: 10
    property string kvantumTheme: ""
    // Qt's interface font, if it has its own ("" = the same as above). Its own is remembered
    // (ShellSettings.qtOwnFont), as it may be the same family and size for now.
    property string qtFont: ""
    property int qtFontSize: 0
    property bool portalDialogs: false

    // Setting -> its value before the first change, for those changed here: dark, gtkTheme,
    // kvantumTheme, iconTheme, cursor (the theme), cursorSize, font, fontSize, monoFont,
    // monoSize, qtFont ("" = the shared one), qtFontSize, portalDialogs
    property var originals: ({})

    function changed(key: string): bool {
        return key in originals;
    }

    // Remembers `before` the first time `key` changes; forgets it once `after` matches again
    function track(key: string, before: var, after: var): void {
        const originals = Object.assign({}, root.originals);
        if (!(key in originals))
            originals[key] = before;
        if (JSON.stringify(originals[key]) === JSON.stringify(after))
            delete originals[key];
        root.originals = originals;
        originalsFile.save(originals);
    }

    function current(key: string): var {
        return key === "cursor" ? cursorTheme : root[key];
    }

    // Forgets originals that match again (e.g. changed back elsewhere), once all is read
    function pruneOriginals(): void {
        const kept = {};
        for (const key in originals) {
            if (JSON.stringify(originals[key]) !== JSON.stringify(current(key)))
                kept[key] = originals[key];
        }
        if (Object.keys(kept).length !== Object.keys(originals).length) {
            originals = kept;
            originalsFile.save(kept);
        }
    }

    function revert(key: string): void {
        const value = originals[key];
        switch (key) {
        case "dark":
            setDark(value);
            break;
        case "gtkTheme":
            setGtkTheme(value);
            break;
        case "kvantumTheme":
            setKvantumTheme(value);
            break;
        case "iconTheme":
            setIconTheme(value);
            break;
        case "cursor":
            setCursor(value, cursorSize);
            break;
        case "cursorSize":
            setCursor(cursorTheme, value);
            break;
        case "font":
            setFont(value, fontSize);
            break;
        case "fontSize":
            setFont(font, value);
            break;
        case "monoFont":
            setMonoFont(value, monoSize);
            break;
        case "monoSize":
            setMonoFont(monoFont, value);
            break;
        // Back to its own font (or the shared one), at the size it had then
        case "qtFont":
            setQtFont(value, originals.qtFontSize ?? (qtFontSize || fontSize));
            break;
        case "qtFontSize":
            setQtFont(qtFont, value);
            break;
        case "portalDialogs":
            setPortalDialogs(value);
            break;
        }
    }

    // What's installed: read when first needed (Settings › Appearance, a preset), not at every
    // start of the shell, which only needs the current icons
    property bool listed: false
    // Waiting for the lists (see afterListed)
    property var listWaiters: []
    // The theme pictures are only for the page, and take a couple of seconds
    property bool wantPreviews: false
    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property var kvantumThemes: []
    property var fonts: []
    property var monoFonts: []

    // Gallery pictures by theme (scripts/theme-previews.py): icons -> [file], cursors ->
    // { pointer, text, hand } PNGs
    property var iconPreviews: ({})
    property var cursorPreviews: ({})
    property string previewedThemes: ""

    // What's installed, again (while the Appearance page is open, for themes installed meanwhile)
    function rescan(): void {
        if (!lists.running)
            lists.running = true;
    }

    // Runs `then` once what's installed is known (straight away if it is)
    function afterListed(then: var): void {
        if (listed) {
            then();
            return;
        }
        listWaiters = [...listWaiters, then];
        rescan();
    }

    // The shell's icons for its next start, in Hyprland's environment (see setIconTheme)
    function setIconEnv(name: string): void {
        Quickshell.execDetached(["hyprctl", "eval", `hl.env("QS_ICON_THEME", ${Exec.lua(name)})`]);
    }

    // GTK 3 or Qt set to something else than the choices above (as nwg-look and qt6ct allow);
    // worked out after reading and after each change (see checkMatch). What differs, as
    // "GTK 3 cursor: <name>" lines
    property var mismatches: []
    readonly property bool mismatched: mismatches.length > 0
    property bool loaded: false

    // Checked once changes settle: a preset writes several files in turn, and halfway through
    // they'd look mismatched
    function checkMatch(): void {
        matchTimer.restart();
    }

    Timer {
        id: matchTimer
        interval: 1500
        onTriggered: root.compareFiles()
    }

    function compareFiles(): void {
        if (!loaded)
            return;
        const found = [];
        const gtk = gtk3.text();
        const compare = (who, what, theirs, ours) => {
            if (theirs !== "" && theirs !== ours)
                found.push(`${who} ${what}: ${theirs}`);
        };
        compare("GTK 3", "icons", ini(gtk, "Settings", "gtk-icon-theme-name"), iconTheme);
        compare("GTK 3", "cursor", ini(gtk, "Settings", "gtk-cursor-theme-name"), cursorTheme);
        compare("GTK 3", "font", ini(gtk, "Settings", "gtk-font-name"), `${font} ${fontSize}`);
        compare("Qt", "icons", ini(qt6ct.text(), "Appearance", "icon_theme"), iconTheme);
        mismatches = found;
    }

    // Qt's own interface font, if it has one: chosen here, or set to another elsewhere (after
    // both are read)
    function readQtFont(): void {
        if (!loaded)
            return;
        const general = ini(qt6ct.text(), "Fonts", "general").replace(/^"|"$/g, "").split(",");
        const family = general[0] ?? "";
        const size = parseInt(general[1] ?? "0");
        qtFont = family !== "" && (ShellSettings.qtOwnFont || family !== font || size !== fontSize) ? family : "";
        qtFontSize = qtFont !== "" ? size : 0;
    }

    // Everything, for the settings page
    function refresh(): void {
        query.running = true;
        wantPreviews = true;
        lists.running = true;
        gtk3.reload();
        gtk4.reload();
        qt6ct.reload();
        kvantum.reload();
    }

    // --- Reading and writing ini files

    // A "key=value" line, or "key = value" as a file edited by hand may have
    function keyLine(key: string): var {
        const escaped = key.replace(/[.*+?^$()|[\]\\{}]/g, "\\$&");
        return new RegExp("^\\s*" + escaped + "\\s*=");
    }

    function ini(text: string, section: string, key: string): string {
        const pattern = keyLine(key);
        let inSection = false;
        for (const line of text.split("\n")) {
            const header = line.match(/^\[(.*)\]\s*$/);
            if (header) {
                inSection = header[1] === section;
                continue;
            }
            const match = inSection ? line.match(pattern) : null;
            if (match)
                return line.slice(match[0].length).trim();
        }
        return "";
    }

    function setIni(text: string, section: string, key: string, value: string): string {
        const lines = text === "" ? [] : text.split("\n");
        let start = lines.findIndex(line => line.trim() === `[${section}]`);
        if (start === -1) {
            if (lines.length > 0 && lines[lines.length - 1] !== "")
                lines.push("");
            lines.push(`[${section}]`, `${key}=${value}`);
            return lines.join("\n") + "\n";
        }
        let end = lines.findIndex((line, i) => i > start && /^\[.*\]\s*$/.test(line));
        if (end === -1)
            end = lines.length;
        const pattern = keyLine(key);
        const at = lines.findIndex((line, i) => i > start && i < end && pattern.test(line));
        if (at !== -1)
            lines[at] = `${key}=${value}`;
        else
            lines.splice(start + 1, 0, `${key}=${value}`);
        return lines.join("\n").replace(/\n*$/, "\n");
    }

    // Text written this turn of the event loop, by path: a FileView's text() only shows a write
    // from the next turn, so several edits in a row (a preset, "Use everywhere") must build on
    // this, or each would undo the one before
    property var written: ({})

    function editIni(file: var, section: string, key: string, value: string): void {
        const text = setIni(written[file.path] ?? file.text(), section, key, value);
        written[file.path] = text;
        file.setText(text);
        Qt.callLater(root.forgetWritten);
    }

    function forgetWritten(): void {
        written = {};
    }

    function setGtkIni(key: string, value: string): void {
        for (const file of [gtk3, gtk4])
            editIni(file, "Settings", key, value);
    }

    function gsettings(key: string, value: string): void {
        Exec.run(`gsettings set org.gnome.desktop.interface ${key} ${Exec.quote(value)}`);
    }

    // Qt's font setting: "Family,size,-1,5,400,…"
    function qtFontString(family: string, size: int): string {
        return `"${family},${size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"`;
    }

    // --- Changes

    // The theme's dark or light sibling, if it has one ("adw-gtk3" <-> "adw-gtk3-dark",
    // "KvArc" <-> "KvArcDark")
    function variant(name: string, list: var, dark: bool): string {
        const base = name.replace(/-?[Dd]ark$/, "");
        if (!dark)
            return list.includes(base) ? base : name;
        return [`${base}-dark`, `${base}Dark`, `${base}-Dark`].find(n => list.includes(n)) ?? name;
    }

    function setDark(dark: bool): void {
        track("dark", root.dark, dark);
        root.dark = dark;
        gsettings("color-scheme", dark ? "prefer-dark" : "default");
        setGtkIni("gtk-application-prefer-dark-theme", dark ? "1" : "0");
        // The themes' siblings, from what's installed
        afterListed(() => {
            const gtk = variant(gtkTheme, gtkThemes, dark);
            if (gtk !== gtkTheme)
                setGtkTheme(gtk);
            const kv = variant(kvantumTheme, kvantumThemes, dark);
            if (kvantumTheme !== "" && kv !== kvantumTheme)
                setKvantumTheme(kv);
        });
    }

    function setGtkTheme(name: string): void {
        track("gtkTheme", gtkTheme, name);
        gtkTheme = name;
        gsettings("gtk-theme", name);
        setGtkIni("gtk-theme-name", name);
    }

    function setKvantumTheme(name: string): void {
        track("kvantumTheme", kvantumTheme, name);
        kvantumTheme = name;
        editIni(kvantum, "General", "theme", name);
    }

    function setIconTheme(name: string): void {
        track("iconTheme", iconTheme, name);
        iconTheme = name;
        gsettings("icon-theme", name);
        setGtkIni("gtk-icon-theme-name", name);
        editIni(qt6ct, "Appearance", "icon_theme", name);
        writeHyprEnv();
        checkMatch();
        // The shell picks its icons at start: restart it with these (and come back here), once
        // whatever else was changed with them is saved
        if (name !== "" && name !== Quickshell.env("QS_ICON_THEME")) {
            setIconEnv(name);
            RestartState.restartShell();
        }
    }

    function setCursor(name: string, size: int): void {
        track("cursor", cursorTheme, name);
        track("cursorSize", cursorSize, size);
        cursorTheme = name;
        cursorSize = size;
        gsettings("cursor-theme", name);
        Exec.run(`gsettings set org.gnome.desktop.interface cursor-size ${size}`);
        setGtkIni("gtk-cursor-theme-name", name);
        setGtkIni("gtk-cursor-theme-size", String(size));
        Exec.run(`hyprctl setcursor ${Exec.quote(name)} ${size}`);
        writeHyprEnv();
        checkMatch();
    }

    // appearance.lua: the cursor and the shell's icons, for what starts after login
    function writeHyprEnv(): void {
        hyprEnv.setText([
            "-- Cursor and the shell's icons set in Quickshell's settings window (Appearance), for apps",
            "-- started after login. Loaded by hyprland.lua after env.lua; this machine's own, kept by",
            "-- the setup script.",
            "",
            `hl.env("HYPRCURSOR_THEME", ${Exec.lua(cursorTheme)})`,
            `hl.env("HYPRCURSOR_SIZE", "${cursorSize}")`,
            `hl.env("XCURSOR_THEME", ${Exec.lua(cursorTheme)})`,
            `hl.env("XCURSOR_SIZE", "${cursorSize}")`,
            ...(iconTheme !== "" ? [`hl.env("QS_ICON_THEME", ${Exec.lua(iconTheme)})`] : []),
            ""
        ].join("\n"));
    }

    function setFont(family: string, size: int): void {
        track("font", font, family);
        track("fontSize", fontSize, size);
        font = family;
        fontSize = size;
        gsettings("font-name", `${family} ${size}`);
        setGtkIni("gtk-font-name", `${family} ${size}`);
        if (qtFont === "")
            editIni(qt6ct, "Fonts", "general", qtFontString(family, size));
        checkMatch();
    }

    function setMonoFont(family: string, size: int): void {
        track("monoFont", monoFont, family);
        track("monoSize", monoSize, size);
        monoFont = family;
        monoSize = size;
        gsettings("monospace-font-name", `${family} ${size}`);
        editIni(qt6ct, "Fonts", "fixed", qtFontString(family, size));
    }

    // Qt's own interface font; "" goes back to the shared one
    function setQtFont(family: string, size: int): void {
        track("qtFont", qtFont, family);
        track("qtFontSize", qtFontSize, family === "" ? 0 : size);
        ShellSettings.qtOwnFont = family !== "";
        qtFont = family;
        qtFontSize = family === "" ? 0 : size;
        editIni(qt6ct, "Fonts", "general", family === "" ? qtFontString(font, fontSize) : qtFontString(family, size));
    }

    function setPortalDialogs(on: bool): void {
        track("portalDialogs", portalDialogs, on);
        portalDialogs = on;
        editIni(qt6ct, "Appearance", "standard_dialogs", on ? "xdgdesktopportal" : "default");
    }

    // Writes the current choices everywhere, fixing toolkits that disagree
    function applyAll(): void {
        ShellSettings.qtOwnFont = false;
        qtFont = "";
        qtFontSize = 0;
        setGtkTheme(gtkTheme);
        setIconTheme(iconTheme);
        setCursor(cursorTheme, cursorSize);
        setFont(font, fontSize);
        setMonoFont(monoFont, monoSize);
        setGtkIni("gtk-application-prefer-dark-theme", dark ? "1" : "0");
        checkMatch();
    }

    // Its own font remembered once the settings have loaded (after the files were read)
    Connections {
        target: ShellSettings

        function onQtOwnFontChanged(): void {
            root.readQtFont();
        }
    }

    // Only gsettings at start (the ini files read themselves): enough to keep the shell's icons
    // following the icon theme
    Component.onCompleted: {
        // Kvantum Manager makes this on first use
        Exec.run(`mkdir -p ${Exec.quote(configDir + "/Kvantum")}`);
        query.running = true;
    }

    // gsettings, one "key value" per line
    Process {
        id: query
        command: ["sh", "-c", "for k in color-scheme gtk-theme icon-theme cursor-theme cursor-size font-name monospace-font-name; do printf '%s %s\\n' $k \"$(gsettings get org.gnome.desktop.interface $k)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const line of text.split("\n")) {
                    const space = line.indexOf(" ");
                    if (space > 0)
                        values[line.slice(0, space)] = line.slice(space + 1).replace(/^'|'$/g, "");
                }
                const splitFont = value => {
                    const match = (value ?? "").match(/^(.*?),?\s+(\d+(?:\.\d+)?)$/);
                    return match ? [match[1].trim(), Math.round(Number(match[2]))] : [value ?? "", 11];
                };
                root.dark = values["color-scheme"] === "prefer-dark";
                root.gtkTheme = values["gtk-theme"] ?? "";
                root.iconTheme = values["icon-theme"] ?? "";
                root.cursorTheme = values["cursor-theme"] ?? "";
                root.cursorSize = parseInt(values["cursor-size"] ?? "24");
                [root.font, root.fontSize] = splitFont(values["font-name"]);
                [root.monoFont, root.monoSize] = splitFont(values["monospace-font-name"]);
                root.loaded = true;
                root.readQtFont();
                root.pruneOriginals();
                root.checkMatch();
                // Icons chosen before the shell followed them (or elsewhere): the shell uses them
                // from its next start
                if (root.iconTheme !== "" && root.iconTheme !== Quickshell.env("QS_ICON_THEME")) {
                    root.writeHyprEnv();
                    root.setIconEnv(root.iconTheme);
                }
            }
        }
    }

    // What's installed, as "kind<TAB>name" lines
    Process {
        id: lists
        command: ["sh", "-c", `
            for d in /usr/share/themes ~/.themes ~/.local/share/themes; do for t in "$d"/*/; do [ -f "$t/gtk-3.0/gtk.css" ] && printf 'gtk\\t%s\\n' "$(basename "$t")"; done; done
            for d in /usr/share/icons ~/.local/share/icons ~/.icons; do for t in "$d"/*/; do
                n=$(basename "$t")
                grep -q '^Directories=.' "$t/index.theme" 2>/dev/null && [ "$n" != hicolor ] && printf 'icons\\t%s\\n' "$n"
                { [ -d "$t/cursors" ] || [ -f "$t/manifest.hl" ]; } && printf 'cursor\\t%s\\n' "$n"
            done; done
            for d in /usr/share/Kvantum ~/.config/Kvantum; do for t in "$d"/*/; do printf 'kvantum\\t%s\\n' "$(basename "$t")"; done; done
            fc-list : family | cut -d, -f1 | sort -u | sed 's/^/font\\t/'
            fc-list :spacing=mono family | cut -d, -f1 | sort -u | sed 's/^/mono\\t/'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = { gtk: [], icons: [], cursor: [], kvantum: [], font: [], mono: [] };
                for (const line of text.split("\n")) {
                    const [kind, name] = line.split("\t");
                    if (found[kind] && name && name !== "*" && !found[kind].includes(name))
                        found[kind].push(name);
                }
                const sort = list => list.sort((a, b) => a.localeCompare(b));
                root.gtkThemes = sort(found.gtk);
                root.iconThemes = sort(found.icons);
                root.cursorThemes = sort(found.cursor);
                root.kvantumThemes = sort(found.kvantum);
                root.fonts = found.font;
                root.monoFonts = found.mono;
                root.listed = true;
                const waiting = root.listWaiters;
                root.listWaiters = [];
                for (const then of waiting)
                    then();
                // Pictures only for the page, and for new themes' sake
                const themes = JSON.stringify([root.iconThemes, root.cursorThemes]);
                if (root.wantPreviews && themes !== root.previewedThemes) {
                    root.previewedThemes = themes;
                    previewer.running = true;
                }
            }
        }
    }

    // After the lists, as it takes a couple of seconds
    Process {
        id: previewer
        command: ["python3", "-I", Quickshell.shellPath("scripts/theme-previews.py"), root.iconThemes.join(","), root.cursorThemes.join(",")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const previews = JSON.parse(text);
                    root.iconPreviews = previews.icons ?? {};
                    root.cursorPreviews = previews.cursors ?? {};
                } catch (e) {}
            }
        }
    }

    // Read synchronously: they're edited in place, and editing one not yet read would replace
    // it with only the changed line
    FileView {
        id: gtk3
        path: `${root.configDir}/gtk-3.0/settings.ini`
        blockLoading: true
        printErrors: false
        onLoaded: root.checkMatch()
    }

    FileView {
        id: gtk4
        path: `${root.configDir}/gtk-4.0/settings.ini`
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: qt6ct
        path: `${root.configDir}/qt6ct/qt6ct.conf`
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.portalDialogs = root.ini(text(), "Appearance", "standard_dialogs") === "xdgdesktopportal";
            root.readQtFont();
            root.checkMatch();
        }
    }

    FileView {
        id: kvantum
        path: `${root.configDir}/Kvantum/kvantum.kvconfig`
        blockLoading: true
        printErrors: false
        onLoaded: root.kvantumTheme = root.ini(text(), "General", "theme")
    }

    JsonFile {
        id: originalsFile
        path: Quickshell.statePath("appearance-originals.json")
        blocking: true
        indent: 2
        onRead: stored => {
            const loaded = Object.assign({}, stored);
            // Saved before sizes were settings of their own: { theme|family, size } pairs
            const pairs = { cursor: ["theme", "cursorSize"], font: ["family", "fontSize"], monoFont: ["family", "monoSize"], qtFont: ["family", "qtFontSize"] };
            for (const key in pairs) {
                const value = loaded[key];
                if (value !== null && typeof value === "object") {
                    loaded[key] = value[pairs[key][0]];
                    loaded[pairs[key][1]] = value.size;
                }
            }
            root.originals = loaded;
        }
    }

    FileView {
        id: hyprEnv
        path: `${root.configDir}/hypr/appearance.lua`
        printErrors: false
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
// forgotten once it's back to that value.
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
    // Qt's interface font, if it differs from the one above ("" = the same)
    property string qtFont: ""
    property int qtFontSize: 0
    property bool portalDialogs: false

    // Setting -> its value before the first change, for those changed here
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
        originalsFile.setText(JSON.stringify(originals, null, 2));
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
            setCursor(value.theme, value.size);
            break;
        case "font":
            setFont(value.family, value.size);
            break;
        case "monoFont":
            setMonoFont(value.family, value.size);
            break;
        case "qtFont":
            setQtFont(value.family, value.size);
            break;
        case "portalDialogs":
            setPortalDialogs(value);
            break;
        }
    }

    // What's installed
    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property var kvantumThemes: []
    property var fonts: []
    property var monoFonts: []

    // GTK 3 or Qt set to something else than the choices above (as nwg-look and qt6ct allow);
    // worked out after reading and after each change (see checkMatch)
    property bool mismatched: false
    property bool loaded: false

    function checkMatch(): void {
        if (!loaded)
            return;
        const gtk = gtk3.text();
        const qtIcons = ini(qt6ct.text(), "Appearance", "icon_theme");
        mismatched = (gtk !== "" && (ini(gtk, "Settings", "gtk-icon-theme-name") !== iconTheme
                    || ini(gtk, "Settings", "gtk-cursor-theme-name") !== cursorTheme
                    || ini(gtk, "Settings", "gtk-font-name") !== `${font} ${fontSize}`))
            || (qtIcons !== "" && qtIcons !== iconTheme);
    }

    // Qt's own interface font, if it isn't the shared one (after both are read)
    function readQtFont(): void {
        if (!loaded)
            return;
        const general = ini(qt6ct.text(), "Fonts", "general").replace(/^"|"$/g, "").split(",");
        const family = general[0] ?? "";
        const size = parseInt(general[1] ?? "0");
        qtFont = family !== "" && (family !== font || size !== fontSize) ? family : "";
        qtFontSize = qtFont !== "" ? size : 0;
    }

    function refresh(): void {
        query.running = true;
        lists.running = true;
        gtk3.reload();
        gtk4.reload();
        qt6ct.reload();
        kvantum.reload();
    }

    // --- Reading and writing ini files

    function ini(text: string, section: string, key: string): string {
        let inSection = false;
        for (const line of text.split("\n")) {
            const header = line.match(/^\[(.*)\]\s*$/);
            if (header) {
                inSection = header[1] === section;
                continue;
            }
            if (inSection && line.startsWith(`${key}=`))
                return line.slice(key.length + 1).trim();
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
        const at = lines.findIndex((line, i) => i > start && i < end && line.startsWith(`${key}=`));
        if (at !== -1)
            lines[at] = `${key}=${value}`;
        else
            lines.splice(start + 1, 0, `${key}=${value}`);
        return lines.join("\n").replace(/\n*$/, "\n");
    }

    function setGtkIni(key: string, value: string): void {
        for (const file of [gtk3, gtk4])
            file.setText(setIni(file.text(), "Settings", key, value));
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
        const gtk = variant(gtkTheme, gtkThemes, dark);
        if (gtk !== gtkTheme)
            setGtkTheme(gtk);
        const kv = variant(kvantumTheme, kvantumThemes, dark);
        if (kvantumTheme !== "" && kv !== kvantumTheme)
            setKvantumTheme(kv);
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
        kvantum.setText(setIni(kvantum.text(), "General", "theme", name));
    }

    function setIconTheme(name: string): void {
        track("iconTheme", iconTheme, name);
        iconTheme = name;
        gsettings("icon-theme", name);
        setGtkIni("gtk-icon-theme-name", name);
        qt6ct.setText(setIni(qt6ct.text(), "Appearance", "icon_theme", name));
        writeHyprEnv();
        checkMatch();
        // The shell picks its icons at start: restart it with these (and come back here), once
        // whatever else was changed with them is saved
        if (name !== "" && name !== Quickshell.env("QS_ICON_THEME")) {
            Exec.run(`hyprctl eval 'hl.env("QS_ICON_THEME", "${name}")'`);
            Exec.viaHyprland("sh -c 'sleep 1; pkill -x qs; while pgrep -x qs >/dev/null; do sleep 0.1; done; qs & sleep 2; qs ipc call settings open appearance'", "");
        }
    }

    function setCursor(name: string, size: int): void {
        track("cursor", { theme: cursorTheme, size: cursorSize }, { theme: name, size: size });
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
            `hl.env("HYPRCURSOR_THEME", "${cursorTheme}")`,
            `hl.env("HYPRCURSOR_SIZE", "${cursorSize}")`,
            `hl.env("XCURSOR_THEME", "${cursorTheme}")`,
            `hl.env("XCURSOR_SIZE", "${cursorSize}")`,
            ...(iconTheme !== "" ? [`hl.env("QS_ICON_THEME", "${iconTheme}")`] : []),
            ""
        ].join("\n"));
    }

    function setFont(family: string, size: int): void {
        track("font", { family: font, size: fontSize }, { family: family, size: size });
        font = family;
        fontSize = size;
        gsettings("font-name", `${family} ${size}`);
        setGtkIni("gtk-font-name", `${family} ${size}`);
        if (qtFont === "")
            qt6ct.setText(setIni(qt6ct.text(), "Fonts", "general", qtFontString(family, size)));
        checkMatch();
    }

    function setMonoFont(family: string, size: int): void {
        track("monoFont", { family: monoFont, size: monoSize }, { family: family, size: size });
        monoFont = family;
        monoSize = size;
        gsettings("monospace-font-name", `${family} ${size}`);
        qt6ct.setText(setIni(qt6ct.text(), "Fonts", "fixed", qtFontString(family, size)));
    }

    // Qt's own interface font; "" goes back to the shared one
    function setQtFont(family: string, size: int): void {
        track("qtFont", { family: qtFont, size: qtFontSize }, { family: family, size: family === "" ? 0 : size });
        qtFont = family;
        qtFontSize = family === "" ? 0 : size;
        qt6ct.setText(setIni(qt6ct.text(), "Fonts", "general", family === "" ? qtFontString(font, fontSize) : qtFontString(family, size)));
    }

    function setPortalDialogs(on: bool): void {
        track("portalDialogs", portalDialogs, on);
        portalDialogs = on;
        qt6ct.setText(setIni(qt6ct.text(), "Appearance", "standard_dialogs", on ? "xdgdesktopportal" : "default"));
    }

    // Writes the current choices everywhere, fixing toolkits that disagree
    function applyAll(): void {
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

    Component.onCompleted: {
        // Kvantum Manager makes this on first use
        Exec.run(`mkdir -p '${configDir}/Kvantum'`);
        refresh();
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
                root.checkMatch();
                // Icons chosen before the shell followed them (or elsewhere): the shell uses them
                // from its next start
                if (root.iconTheme !== "" && root.iconTheme !== Quickshell.env("QS_ICON_THEME")) {
                    root.writeHyprEnv();
                    Exec.run(`hyprctl eval 'hl.env("QS_ICON_THEME", "${root.iconTheme}")'`);
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

    FileView {
        id: originalsFile
        path: Quickshell.statePath("appearance-originals.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.originals = JSON.parse(text());
            } catch (e) {
                root.originals = {};
            }
        }
    }

    FileView {
        id: hyprEnv
        path: `${root.configDir}/hypr/appearance.lua`
        printErrors: false
    }
}

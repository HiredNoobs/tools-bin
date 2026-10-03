pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Default apps for Settings › Default apps, in place of selectdefaultapplication. Which apps
// can open what comes from the MIME caches pacman keeps up to date (plus ~/.local's own .desktop
// files, which have no cache); the current defaults from `xdg-mime query default`, which reads
// mimeapps.list the way xdg-open does. Choices go in ~/.config/mimeapps.list. Each category owns
// its file types: picking an app sets all of a category's listed types, or, for images, video
// and audio, every one of those types the app can open. It removes the category's other entries,
// so no type is left on the previous app. The value from before a category's first change is
// kept (in Quickshell's state folder) for the settings window's ↺.
// Single file types can be set apart from their category (overrides, kept in the state folder
// too): the category then leaves them alone, until the override is removed and the type goes
// back to the category's app. Their names and extensions come from the shared MIME database.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`

    // `primary` lists the apps offered and shows the current default. A category's types are
    // `types`, or every type starting with `prefix` (images, video, audio).
    readonly property var categories: [
        { key: "browser", title: "Web browser", description: "Links and web pages.", primary: "x-scheme-handler/https", types: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"] },
        { key: "mail", title: "Email", description: "Email links (mailto:).", primary: "x-scheme-handler/mailto", types: ["x-scheme-handler/mailto"] },
        { key: "files", title: "Files", description: "Folders, e.g. a drive's Open.", primary: "inode/directory", types: ["inode/directory"] },
        { key: "text", title: "Text editor", description: "Plain text, Markdown, scripts and config files.", primary: "text/plain", types: ["text/plain", "text/markdown", "text/x-markdown", "text/csv", "text/x-log", "application/json", "application/xml", "application/toml", "application/x-yaml", "application/x-shellscript", "text/x-python", "text/x-csrc", "text/x-chdr", "text/x-c++src", "text/x-c++hdr"] },
        { key: "images", title: "Images", description: "Photos, screenshots and other pictures.", primary: "image/png", prefix: "image/" },
        { key: "video", title: "Video", primary: "video/mp4", prefix: "video/" },
        { key: "music", title: "Music", description: "Songs and other audio files.", primary: "audio/mpeg", prefix: "audio/" },
        { key: "pdf", title: "PDF documents", primary: "application/pdf", types: ["application/pdf"] }
    ]

    // MIME type -> the desktop ids that can open it
    property var handlers: ({})
    // Category key -> its current default's desktop id ("" = none)
    property var defaults: ({})
    // MIME type -> the desktop id mimeapps.list sets for it
    property var explicit: ({})
    // Every known type, as { type, name, globs }: the MIME database's, and link schemes apps open
    property var fileTypes: []
    // Types set apart from their category
    property var overrides: []

    function category(key: string): var {
        return categories.find(c => c.key === key);
    }

    function inCategory(cat: var, type: string): bool {
        return cat.prefix ? type.startsWith(cat.prefix) : cat.types.includes(type);
    }

    // Apps offered for a category: those that open its primary type (and the current default,
    // even if it doesn't say so), as { id, name, icon }, by name
    function apps(key: string): var {
        const cat = category(key);
        const ids = (handlers[cat.primary] ?? []).slice();
        const current = defaults[key] ?? "";
        if (current !== "" && !ids.includes(current))
            ids.push(current);
        return ids.map(id => {
            const entry = DesktopEntries.byId(id.replace(/\.desktop$/, ""));
            return { id: id, name: entry?.name || id.replace(/\.desktop$/, ""), icon: entry?.icon ?? "", hidden: entry?.noDisplay ?? false };
        }).filter(app => !app.hidden || app.id === current).sort((a, b) => a.name.localeCompare(b.name));
    }

    function app(id: string): var {
        const entry = DesktopEntries.byId(id.replace(/\.desktop$/, ""));
        return { id: id, name: entry?.name || id.replace(/\.desktop$/, ""), icon: entry?.icon ?? "" };
    }

    // Apps that say they open `type`, by name
    function typeApps(type: string): var {
        return (handlers[type] ?? []).map(id => app(id)).sort((a, b) => a.name.localeCompare(b.name));
    }

    // Every app with a launcher entry, for opening a type with an app that doesn't list it
    function allApps(): var {
        return DesktopEntries.applications.values.filter(entry => !entry.noDisplay).map(entry => app(`${entry.id}.desktop`)).sort((a, b) => a.name.localeCompare(b.name));
    }

    // The app a type opens with: mimeapps.list's, else the first that says it opens it (as
    // xdg-open falls back to), with `automatic` set for the latter
    function typeDefault(type: string): var {
        if (explicit[type])
            return { id: explicit[type], automatic: false };
        return { id: (handlers[type] ?? [])[0] ?? "", automatic: true };
    }

    function typeInfo(type: string): var {
        return fileTypes.find(t => t.type === type) ?? { type: type, name: type, globs: [] };
    }

    function categoryOf(type: string): var {
        return categories.find(cat => inCategory(cat, type));
    }

    function overridesIn(key: string): int {
        const cat = category(key);
        return overrides.filter(type => inCategory(cat, type)).length;
    }

    // Types matching a search: an extension ("md", ".md", "*.md"), a name or a MIME type.
    // Exact extensions first, then those starting with it, then the rest.
    function findTypes(query: string, limit: int): var {
        const q = query.trim().toLowerCase().replace(/^\*?\./, "");
        if (q === "")
            return [];
        const scored = [];
        for (const t of fileTypes) {
            const exts = t.globs.map(g => g.toLowerCase().replace(/^\*\./, ""));
            let score = -1;
            if (exts.includes(q))
                score = 0;
            else if (t.type === q)
                score = 0;
            else if (exts.some(e => e.startsWith(q)) || t.name.toLowerCase().startsWith(q))
                score = 1;
            else if (t.type.includes(q) || t.name.toLowerCase().includes(q))
                score = 2;
            if (score >= 0)
                scored.push({ score: score, t: t });
        }
        // Types something opens before the rest (Markdown before the Genesis ROMs that share .md)
        const opened = t => explicit[t.type] || handlers[t.type] ? 0 : 1;
        scored.sort((a, b) => a.score - b.score || opened(a.t) - opened(b.t) || a.t.name.localeCompare(b.t.name));
        return scored.slice(0, limit).map(s => s.t);
    }

    function appName(id: string): string {
        if (id === "")
            return "";
        const entry = DesktopEntries.byId(id.replace(/\.desktop$/, ""));
        return entry?.name || id.replace(/\.desktop$/, "");
    }

    // --- The ↺ buttons

    // Category key -> its default before the first change, for those changed here
    property var originals: ({})

    function changed(key: string): bool {
        return key in originals;
    }

    function revert(key: string): void {
        if (key in originals)
            setDefault(key, originals[key]);
    }

    // --- Changing a default

    // `id` "" removes the category's entries, back to whatever the system picks
    function setDefault(key: string, id: string): void {
        const cat = category(key);
        const before = defaults[key] ?? "";

        const originals = Object.assign({}, root.originals);
        if (!(key in originals))
            originals[key] = before;
        if (originals[key] === id)
            delete originals[key];
        root.originals = originals;
        originalsFile.setText(JSON.stringify(originals, null, 2));

        // A listed category's types all go to the app (a text editor opens any of them, whatever
        // its .desktop file lists); of a prefix's, only those it can open
        let types = [];
        if (id !== "" && cat.prefix) {
            types = Object.keys(handlers).filter(type => inCategory(cat, type) && handlers[type].includes(id)).sort();
            // Kept even if the app doesn't list it (an app offered as the current default)
            if (!types.includes(cat.primary))
                types.unshift(cat.primary);
        } else if (id !== "") {
            types = cat.types;
        }

        const own = type => inCategory(cat, type) && !overrides.includes(type);
        writeDefaults(own, types.filter(type => !overrides.includes(type)), id);
    }

    // One type set apart from its category
    function setType(type: string, id: string): void {
        if (!overrides.includes(type))
            saveOverrides([...overrides, type].sort());
        writeDefaults(t => t === type, [type], id);
    }

    // Back to its category's app, or to the system's pick if no category has it
    function removeOverride(type: string): void {
        saveOverrides(overrides.filter(t => t !== type));
        const cat = categoryOf(type);
        const id = cat ? defaults[cat.key] ?? "" : "";
        const follows = id !== "" && (!cat.prefix || (handlers[type] ?? []).includes(id));
        writeDefaults(t => t === type, follows ? [type] : [], id);
    }

    function saveOverrides(list: var): void {
        root.overrides = list;
        overridesFile.setText(JSON.stringify(list, null, 2));
    }

    function writeDefaults(own: var, types: var, id: string): void {
        mimeapps.reload();
        mimeapps.setText(withDefaults(mimeapps.text(), own, types, id));
        refresh();
    }

    // mimeapps.list with the [Default Applications] lines of types `own` accepts replaced by
    // `types` -> `id`. Other sections and lines are kept as they are.
    function withDefaults(text: string, own: var, types: var, id: string): string {
        const lines = text.split("\n");
        while (lines.length > 0 && lines[lines.length - 1].trim() === "")
            lines.pop();
        const added = types.map(type => `${type}=${id}`);

        let start = lines.findIndex(line => line.trim() === "[Default Applications]");
        if (start < 0) {
            if (added.length === 0)
                return text;
            if (lines.length > 0)
                lines.push("");
            return [...lines, "[Default Applications]", ...added, ""].join("\n");
        }
        let end = lines.findIndex((line, i) => i > start && line.trim().startsWith("["));
        if (end < 0)
            end = lines.length;

        const kept = lines.slice(start + 1, end).filter(line => {
            const eq = line.indexOf("=");
            return eq < 0 || !own(line.slice(0, eq).trim());
        });
        // New lines go after the section's last entry, before any blank lines ending it
        let at = kept.length;
        while (at > 0 && kept[at - 1].trim() === "")
            at--;
        kept.splice(at, 0, ...added);
        // Blank lines only separate it from a section after it
        if (end === lines.length)
            kept.length = at + added.length;
        return [...lines.slice(0, start + 1), ...kept, ...lines.slice(end), ""].join("\n");
    }

    function refresh(): void {
        mimeapps.reload();
        readExplicit();
        scan.running = true;
    }

    function readExplicit(): void {
        const explicit = {};
        let inSection = false;
        for (const line of mimeapps.text().split("\n")) {
            const trimmed = line.trim();
            if (trimmed.startsWith("["))
                inSection = trimmed === "[Default Applications]";
            const eq = trimmed.indexOf("=");
            if (inSection && eq > 0) {
                const id = trimmed.slice(eq + 1).split(";").find(id => id !== "");
                if (id)
                    explicit[trimmed.slice(0, eq).trim()] = id;
            }
        }
        root.explicit = explicit;
    }

    Component.onCompleted: refresh()

    // "h<TAB>type<TAB>id;id;" for what each app opens, "d<TAB>key<TAB>id" for the defaults,
    // "g<TAB>type<TAB>glob" and "c<TAB>type<TAB>name" from the MIME database
    Process {
        id: scan
        command: ["sh", "-c", `
            for d in /usr/share/applications /usr/local/share/applications ~/.local/share/applications; do
                [ -f "$d/mimeinfo.cache" ] && sed -n 's/^\\([^=[]*\\)=\\(.*\\)/h\\t\\1\\t\\2/p' "$d/mimeinfo.cache"
            done
            for f in ~/.local/share/applications/*.desktop; do
                [ -f "$f" ] || continue
                id=$(basename "$f")
                sed -n 's/^MimeType=//p' "$f" | tr ';' '\\n' | while read -r t; do [ -n "$t" ] && printf 'h\\t%s\\t%s;\\n' "$t" "$id"; done
            done
            ${root.categories.map(c => `printf 'd\\t%s\\t%s\\n' ${c.key} "$(xdg-mime query default ${c.primary})"`).join("\n")}
            sed -n 's/^[0-9]*:\\([^:]*\\):\\([^:]*\\).*/g\\t\\1\\t\\2/p' /usr/share/mime/globs2
            grep -m1 -H '<comment>' /usr/share/mime/*/*.xml | sed -n 's|^/usr/share/mime/\\([^:]*\\)\\.xml:.*<comment>\\(.*\\)</comment>.*|c\\t\\1\\t\\2|p'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const handlers = {};
                const defaults = {};
                const types = {};
                const type = name => types[name] ?? (types[name] = { type: name, name: "", globs: [] });
                for (const line of text.split("\n")) {
                    const [kind, a, b] = line.split("\t");
                    if (kind === "h" && a) {
                        const ids = handlers[a] ?? (handlers[a] = []);
                        for (const id of (b ?? "").split(";"))
                            if (id !== "" && !ids.includes(id))
                                ids.push(id);
                    } else if (kind === "d" && a) {
                        defaults[a] = (b ?? "").trim();
                    } else if (kind === "g" && a && b && !type(a).globs.includes(b)) {
                        type(a).globs.push(b);
                    } else if (kind === "c" && a && b) {
                        type(a).name = b;
                    }
                }
                // Link schemes aren't in the MIME database
                for (const name of Object.keys(handlers))
                    if (name.startsWith("x-scheme-handler/"))
                        type(name).name = `${name.slice(17)}: links`;
                root.handlers = handlers;
                root.defaults = defaults;
                // Only types with a file extension or an app that opens them
                root.fileTypes = Object.values(types).filter(t => t.globs.length > 0 || handlers[t.type]).map(t => Object.assign(t, { name: t.name || t.type }));
            }
        }
    }

    // Read synchronously and edited in place, so editing never replaces lines not read yet
    FileView {
        id: mimeapps
        path: `${root.configDir}/mimeapps.list`
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    FileView {
        id: overridesFile
        path: Quickshell.statePath("default-apps-overrides.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.overrides = JSON.parse(text());
            } catch (e) {
                root.overrides = [];
            }
        }
    }

    FileView {
        id: originalsFile
        path: Quickshell.statePath("default-apps-originals.json")
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
}

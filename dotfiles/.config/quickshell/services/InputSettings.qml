pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard, mouse and touchpad settings for Settings › Keyboard and mouse. Read from Hyprland
// (`hyprctl getoption`), changed live (`hyprctl eval 'hl.config(...)'`) and saved to
// ~/.config/hypr/input.lua, which hyprland.lua loads after the machine file. Like
// monitors.lua it's this machine's own: not in the repo, and kept by the setup script's rsync.
// Only options you've changed are saved (listed in the file's first line, with the config's
// value from before the first change), once Hyprland has taken the change; resetting one drops
// it and sets that value again live (not a config reload, which would also undo live changes
// elsewhere, such as the monitors), and setting it back to that value by hand drops it too.
Singleton {
    id: root

    // Option ("input.touchpad.tap_to_click") -> value, for the options below
    property var values: ({})
    property bool loaded: false
    property bool hasSaved: false
    property string lastError: ""
    // Options changed from here, saved in input.lua, and their values before the first change
    property var custom: []
    property var defaults: ({})

    readonly property string savedPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/input.lua"

    // The options managed here
    readonly property var options: [
        "input.kb_layout", "input.kb_variant", "input.kb_options",
        "input.repeat_rate", "input.repeat_delay", "input.numlock_by_default",
        "input.sensitivity", "input.accel_profile", "input.natural_scroll", "input.left_handed",
        "input.scroll_factor",
        "input.touchpad.natural_scroll", "input.touchpad.tap_to_click", "input.touchpad.tap_and_drag",
        "input.touchpad.disable_while_typing", "input.touchpad.scroll_factor", "input.touchpad.clickfinger_behavior"
    ]

    function get(option: string): var {
        return values[option];
    }

    function isCustom(option: string): bool {
        return custom.includes(option);
    }

    function set(option: string, value: var): void {
        setMany({ [option]: value });
    }

    // Several at once, in one change (e.g. layouts with their variants). Shown straight away;
    // saved once Hyprland has taken it, or read back from Hyprland if it didn't
    function setMany(changes: var): void {
        const before = {};
        for (const option of Object.keys(changes))
            before[option] = values[option];
        values = Object.assign({}, values, changes);
        run(`hl.config(${lua(nest(changes))})`, ok => {
            if (!ok) {
                refresh();
                return;
            }
            const defaults = Object.assign({}, root.defaults);
            let changed = [...custom];
            for (const [option, value] of Object.entries(changes)) {
                if (!changed.includes(option))
                    defaults[option] = before[option];
                // Back at its original value: no longer a change
                if (value === defaults[option]) {
                    changed = changed.filter(o => o !== option);
                    delete defaults[option];
                } else if (!changed.includes(option)) {
                    changed.push(option);
                }
            }
            root.defaults = defaults;
            custom = changed;
            save();
        });
    }

    // Back to the config's values: dropped from input.lua, and the value from before the first
    // change set again. One without a value kept (an older input.lua) needs the config reloaded.
    function reset(resetOptions: var): void {
        const restore = {};
        let reloadConfig = false;
        const defaults = Object.assign({}, root.defaults);
        for (const option of resetOptions) {
            if (option in defaults)
                restore[option] = defaults[option];
            else
                reloadConfig = true;
            delete defaults[option];
        }
        custom = custom.filter(option => !resetOptions.includes(option));
        root.defaults = defaults;
        save();
        if (Object.keys(restore).length > 0) {
            values = Object.assign({}, values, restore);
            run(`hl.config(${lua(nest(restore))})`, ok => {
                if (!ok)
                    refresh();
            });
        }
        // Once the file's rewritten (straight away: blockWrites) or gone
        if (reloadConfig) {
            Exec.run(custom.length === 0 ? `rm -f ${Exec.quote(savedPath)}; hyprctl reload` : "hyprctl reload");
            refreshTimer.restart();
        }
    }

    // { "input.touchpad.x": 1 } -> { input: { touchpad: { x: 1 } } }
    function nest(flat: var): var {
        const tree = {};
        for (const [path, value] of Object.entries(flat)) {
            const keys = path.split(".");
            let node = tree;
            for (const key of keys.slice(0, -1))
                node = node[key] = node[key] ?? {};
            node[keys[keys.length - 1]] = value;
        }
        return tree;
    }

    // A value as Lua (strings quoted, tables written out). `indent` is untyped: a typed string
    // parameter left out arrives as the text "undefined".
    function lua(value: var, indent: var): string {
        indent = indent ?? "";
        if (typeof value === "string")
            return Exec.lua(value);
        if (typeof value === "object" && value !== null) {
            const inner = indent + "    ";
            const fields = Object.entries(value).map(([key, item]) => `${inner}${key} = ${lua(item, inner)}`);
            return `{\n${fields.join(",\n")}\n${indent}}`;
        }
        return String(value);
    }

    function save(): void {
        if (custom.length === 0) {
            Exec.run(`rm -f ${Exec.quote(savedPath)}`);
            hasSaved = false;
            return;
        }
        const settings = {};
        for (const option of custom) {
            if (values[option] !== undefined)
                settings[option] = values[option];
        }
        const lines = [
            `-- options: ${custom.join(",")}`,
            `-- defaults: ${JSON.stringify(defaults)}`,
            "-- Keyboard, mouse and touchpad settings saved from Quickshell's settings window.",
            "-- Loaded by hyprland.lua after the machine file; kept by the setup script's rsync.",
            "-- Delete this file (or use the reset buttons in settings) to go back to the config's.",
            "",
            `hl.config(${lua(nest(settings))})`,
            ""
        ];
        savedFile.setText(lines.join("\n"));
        hasSaved = true;
    }

    function refresh(): void {
        query.running = true;
    }

    // In order through HyprLua: a change made while one is still running waits for it.
    // `done(ok)` runs once Hyprland has answered.
    function run(code: string, done: var): void {
        HyprLua.run(code, (ok, output) => {
            root.lastError = ok ? "" : output;
            done?.(ok);
        });
    }

    Component.onCompleted: refresh()

    // Every option's current value, one JSON object per line
    Process {
        id: query
        command: ["sh", "-c", root.options.map(option => `hyprctl getoption ${option.replace(/\./g, ":")} -j | tr -d '\\n'; echo`).join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const line of text.split("\n")) {
                    try {
                        const result = JSON.parse(line);
                        const option = result.option.replace(/:/g, ".");
                        let value = result.str ?? result.int ?? result.float ?? result.bool;
                        if (value === "[[EMPTY]]")
                            value = "";
                        values[option] = value;
                    } catch (e) {}
                }
                root.values = values;
                root.loaded = true;
            }
        }
    }


    Timer {
        id: refreshTimer
        interval: 800
        onTriggered: root.refresh()
    }

    FileView {
        id: savedFile
        path: root.savedPath
        blockWrites: true
        printErrors: false
        onLoaded: {
            root.hasSaved = true;
            const header = text().match(/^-- options: (.*)$/m);
            root.custom = header ? header[1].split(",").filter(o => o !== "") : [];
            const defaults = text().match(/^-- defaults: (.*)$/m);
            try {
                root.defaults = defaults ? JSON.parse(defaults[1]) : {};
            } catch (e) {
                root.defaults = {};
            }
        }
        onLoadFailed: root.hasSaved = false
    }
}

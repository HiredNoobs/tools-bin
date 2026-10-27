pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Connected monitors and live changes to them through Hyprland's Lua (`hl.monitor`).
// `save()` writes the live layout to ~/.config/hypr/monitors.lua, which hyprland.lua loads.
// Changes that could leave a screen blank (resolution, scale, rotation, on/off, mirroring) are
// undone after 15 seconds unless kept (`keep()`), like other desktops' "Keep these settings?".
Singleton {
    id: root

    // [{ name, model, mode, modes, scale, x, y, width, height, logicalWidth, logicalHeight,
    //    disabled, mirrorOf, transform (0-7, 1/3 = 90°/270°), vrr }]
    property var monitors: []
    readonly property var enabledMonitors: monitors.filter(m => !m.disabled)
    property string lastError: ""

    readonly property string savedPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/monitors.lua"
    property bool hasSaved: false

    readonly property var scales: [1, 1.25, 1.5, 2]
    // Finer steps for the settings window
    readonly property var allScales: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    // The layout to go back to while a risky change waits to be kept, and the seconds left
    property var revertTo: null
    property int revertIn: 0
    readonly property bool confirming: revertTo !== null

    // Before a risky change: remember the layout (unless already waiting) and (re)start the count
    function guard(): void {
        if (!revertTo)
            revertTo = monitors.map(m => specOf(m));
        revertIn = 15;
        countdown.restart();
    }

    function keep(): void {
        revertTo = null;
        countdown.stop();
    }

    function revert(): void {
        if (!revertTo)
            return;
        const specs = revertTo;
        revertTo = null;
        countdown.stop();
        // Turn screens on before any are turned off, so one always stays on. On ones say so:
        // hl.monitor merges, so a screen the change turned off would otherwise stay off
        const ordered = [...specs.filter(s => !s.disabled).map(s => Object.assign({ disabled: false }, s)), ...specs.filter(s => s.disabled)];
        run(ordered.map(spec => luaSpec(spec)).join("\n"));
    }

    function refresh(): void {
        query.running = true;
    }

    // A laptop's own screen, by its connector: eDP, or LVDS (older) or DSI (some thin ones)
    function isBuiltIn(name: string): bool {
        return /^(eDP|LVDS|DSI)/.test(name);
    }

    function byName(name: string): var {
        return monitors.find(m => m.name === name) ?? null;
    }

    // The first other enabled monitor, which arrangement is relative to
    function otherOf(name: string): var {
        return enabledMonitors.find(m => m.name !== name) ?? null;
    }

    // Lua table literal for hl.monitor
    function luaSpec(spec: var): string {
        const fields = Object.entries(spec).map(([key, value]) => {
            const literal = typeof value === "string" ? Exec.lua(value) : String(value);
            return `${key} = ${literal}`;
        });
        return `hl.monitor({ ${fields.join(", ")} })`;
    }

    // Current settings of a monitor as an hl.monitor spec
    function specOf(monitor: var): var {
        if (monitor.disabled)
            return { output: monitor.name, disabled: true };
        // Mirror stated even when empty: hl.monitor merges, so leaving it out wouldn't clear one
        return { output: monitor.name, mode: monitor.mode, position: `${monitor.x}x${monitor.y}`, scale: monitor.scale, transform: monitor.transform, vrr: monitor.vrr ? 1 : 0, mirror: monitor.mirrorOf };
    }

    // The other enabled screens pinned as they are. Rules with an automatic position (the
    // laptop's machine file) are placed again whenever any monitor changes, which can move a
    // screen that wasn't touched. Their full settings are stated: a new rule for one output
    // with only a position would leave the rest (scale!) to Hyprland's defaults.
    function pinOthers(name: string): string {
        return enabledMonitors.filter(m => m.name !== name).map(m => luaSpec(specOf(m))).join("\n");
    }

    // hl.monitor merges into the output's existing rule, so live changes state everything
    // explicitly: a leftover `disabled = true` or `mirror` would otherwise stick
    function apply(name: string, changes: var): void {
        const monitor = byName(name);
        if (!monitor)
            return;
        run(pinOthers(name) + "\n" + luaSpec(Object.assign({
            output: name,
            mode: monitor.mode,
            position: `${monitor.x}x${monitor.y}`,
            scale: monitor.scale,
            transform: monitor.transform,
            vrr: monitor.vrr ? 1 : 0,
            mirror: monitor.mirrorOf,
            disabled: false
        }, changes)));
    }

    function setEnabled(name: string, on: bool): void {
        const monitor = byName(name);
        if (!monitor)
            return;
        if (!on) {
            if (enabledMonitors.length <= 1) {
                lastError = "Can't turn off the only active screen";
                return;
            }
            guard();
            run(pinOthers(name) + "\n" + luaSpec({ output: name, disabled: true }));
            return;
        }
        // Back on: preferred mode, placed automatically
        guard();
        run(pinOthers(name) + "\n" + luaSpec({ output: name, mode: "preferred", position: "auto", scale: 1, mirror: "", disabled: false }));
    }

    // Turning a screen off or back on to a known spec without asking to keep it (the laptop
    // screen when its lid closes and opens, see Lid)
    function setOffQuietly(name: string): void {
        run(pinOthers(name) + "\n" + luaSpec({ output: name, disabled: true }));
    }

    function restoreQuietly(spec: var): void {
        run(pinOthers(spec.output) + "\n" + luaSpec(Object.assign({ disabled: false }, spec)));
    }

    function setMode(name: string, mode: string): void {
        guard();
        apply(name, { mode: mode });
    }

    function setScale(name: string, scale: real): void {
        guard();
        apply(name, { scale: scale });
    }

    function setTransform(name: string, transform: int): void {
        guard();
        apply(name, { transform: transform });
    }

    function setVrr(name: string, on: bool): void {
        apply(name, { vrr: on ? 1 : 0 });
    }

    // Show the same picture as another screen ("" stops mirroring)
    function setMirror(name: string, target: string): void {
        if (target !== "")
            guard();
        apply(name, { mirror: target });
    }

    // Top-left corner in the layout, in logical pixels (from dragging in the settings window)
    function setPosition(name: string, x: int, y: int): void {
        apply(name, { position: `${Math.round(x)}x${Math.round(y)}`, mirror: "" });
    }

    // relation: "left", "right", "above", "below" or "mirror", relative to otherOf(name)
    function arrange(name: string, relation: string): void {
        const monitor = byName(name);
        const other = otherOf(name);
        if (!monitor || !other)
            return;
        if (relation === "mirror") {
            guard();
            apply(name, { mirror: other.name });
            return;
        }
        const positions = {
            "right": [other.x + other.logicalWidth, other.y],
            "left": [other.x - monitor.logicalWidth, other.y],
            "above": [other.x, other.y - monitor.logicalHeight],
            "below": [other.x, other.y + other.logicalHeight]
        };
        const [x, y] = positions[relation];
        apply(name, { position: `${Math.round(x)}x${Math.round(y)}`, mirror: "" });
    }

    // Which arrangement the monitor is currently in, for highlighting
    function relationOf(name: string): string {
        const monitor = byName(name);
        const other = otherOf(name);
        if (!monitor || !other)
            return "";
        if (monitor.mirrorOf === other.name)
            return "mirror";
        const near = (a, b) => Math.abs(a - b) < 2;
        if (near(monitor.x, other.x + other.logicalWidth))
            return "right";
        if (near(monitor.x + monitor.logicalWidth, other.x))
            return "left";
        if (near(monitor.y + monitor.logicalHeight, other.y))
            return "above";
        if (near(monitor.y, other.y + other.logicalHeight))
            return "below";
        return "";
    }

    // A laptop screen that's off is never saved off, as the next start may have no other
    // screen: while its closed lid has it off (Lid) it's saved as it was before, otherwise it's
    // left to the machine config
    function save(): void {
        // Not a change that's waiting to be kept or undone
        if (confirming)
            return;
        const saved = m => {
            if (!m.disabled || !isBuiltIn(m.name))
                return luaSpec(specOf(m));
            if (Lid.laptopSpec?.output === m.name)
                return luaSpec(Lid.laptopSpec);
            return `-- ${m.name} is off, but left to the machine config (it may be the only screen next time)`;
        };
        const lines = [
            "-- Monitor layout saved from the Quickshell display panel.",
            "-- Loaded by hyprland.lua after the machine file; kept by the setup script's rsync.",
            "-- Delete this file (or use \"Use defaults\" in the panel) to go back to the machine config.",
            "",
            ...monitors.map(saved),
            ""
        ];
        savedFile.setText(lines.join("\n"));
        hasSaved = true;
    }

    function resetSaved(): void {
        Exec.run(`rm -f ${Exec.quote(savedPath)} && hyprctl reload`);
        hasSaved = false;
        refreshTimer.restart();
    }

    // In order through HyprLua: a change made while one is still running (the lid closing just
    // after a click in the panel) waits for it
    function run(lua: string): void {
        HyprLua.run(lua, (ok, output) => {
            root.lastError = ok ? "" : output;
            refreshTimer.restart();
            repaintTimer.restart();
        });
    }

    function parse(json: string): void {
        const all = JSON.parse(json);
        // mirrorOf is the mirrored monitor's id ("none" when not mirroring)
        const nameOfId = id => all.find(m => String(m.id) === String(id))?.name ?? "";

        monitors = all.map(m => {
            // Rotated by 90/270 degrees swaps width and height
            const rotated = m.transform % 2 === 1;
            const width = rotated ? m.height : m.width;
            const height = rotated ? m.width : m.height;
            return {
                name: m.name,
                model: [m.make, m.model].filter(part => part).join(" "),
                mode: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`,
                // "1920x1080@59.98Hz" -> "1920x1080@59.98", duplicates removed
                modes: [...new Set(m.availableModes.map(mode => mode.replace(/Hz$/, "")))],
                scale: m.scale,
                x: m.x,
                y: m.y,
                width: width,
                height: height,
                logicalWidth: width / m.scale,
                logicalHeight: height / m.scale,
                disabled: m.disabled,
                mirrorOf: m.mirrorOf === "none" ? "" : nameOfId(m.mirrorOf),
                transform: m.transform,
                vrr: m.vrr
            };
        });
    }

    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parse(text);
                } catch (e) {
                    root.lastError = "Couldn't read monitors";
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                refreshTimer.restart();
        }
    }

    // After a layout change Hyprland can leave the other screen (wallpaper and bar) drawn in its
    // old place until the next input event; a renderer reload repaints every screen
    Timer {
        id: repaintTimer
        interval: 400
        onTriggered: Hyprland.dispatch("hl.dsp.force_renderer_reload()")
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            if (--root.revertIn <= 0)
                root.revert();
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        onTriggered: root.refresh()
    }

    FileView {
        id: savedFile
        path: root.savedPath
        printErrors: false
        onLoaded: root.hasSaved = true
        onLoadFailed: root.hasSaved = false
    }
}

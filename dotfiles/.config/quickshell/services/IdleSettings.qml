pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Idle timeouts for Settings › Power and idle: lock, screen off and suspend, each on battery
// and on AC, in seconds (0 = never). The defaults are the dotfiles' hypridle.conf; changes are
// written to ~/.config/hypr/hypridle.local.conf (this machine's own, like monitors.lua), which
// hyprland.lua's autostart runs hypridle with when it exists, and hypridle is restarted to
// pick them up. Resetting everything deletes the local file.
Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr"
    readonly property string defaultPath: `${configDir}/hypridle.conf`
    readonly property string localPath: `${configDir}/hypridle.local.conf`

    readonly property var kinds: ["lock", "screen", "suspend"]
    // { lock: { battery, ac }, screen: {…}, suspend: {…} }
    property var defaults: ({})
    property var values: ({})
    // The default config's general { } block, copied into the local one
    property string generalBlock: ""
    property bool hasLocal: false
    property bool loaded: false

    function get(kind: string, power: string): int {
        return values[kind]?.[power] ?? 0;
    }

    function isCustom(kind: string): bool {
        return get(kind, "battery") !== (defaults[kind]?.battery ?? 0) || get(kind, "ac") !== (defaults[kind]?.ac ?? 0);
    }

    function set(kind: string, power: string, seconds: int): void {
        const values = JSON.parse(JSON.stringify(root.values));
        values[kind] = Object.assign({}, values[kind], { [power]: seconds });
        root.values = values;
        apply();
    }

    function reset(kind: string): void {
        const values = JSON.parse(JSON.stringify(root.values));
        values[kind] = Object.assign({}, defaults[kind]);
        root.values = values;
        apply();
    }

    // Writes the local config (or deletes it when nothing differs) and restarts hypridle
    function apply(): void {
        const custom = kinds.some(kind => isCustom(kind));
        if (custom) {
            localFile.setText(generate());
            hasLocal = true;
            restart.command = ["sh", "-c", `sleep 0.3; pkill -x hypridle; hyprctl dispatch 'hl.dsp.exec_cmd("hypridle -c ${localPath}")'`];
        } else {
            hasLocal = false;
            restart.command = ["sh", "-c", `rm -f '${localPath}'; pkill -x hypridle; hyprctl dispatch 'hl.dsp.exec_cmd("hypridle")'`];
        }
        restart.running = true;
    }

    // { lock: { battery, ac }, … } from a hypridle config's listeners
    function parse(text: string): var {
        const result = { lock: { battery: 0, ac: 0 }, screen: { battery: 0, ac: 0 }, suspend: { battery: 0, ac: 0 } };
        // Up to the block's own closing brace, on a line of its own (commands contain braces)
        const blocks = text.match(/^listener\s*\{[\s\S]*?^\}/gm) ?? [];
        for (const block of blocks) {
            const timeout = parseInt(block.match(/timeout\s*=\s*(\d+)/)?.[1] ?? "0");
            const action = block.match(/on-timeout\s*=\s*(.*)/)?.[1] ?? "";
            const kind = action.includes("lock-session") ? "lock" : action.includes("dpms") ? "screen" : action.includes("suspend") ? "suspend" : "";
            if (kind === "")
                continue;
            const battery = /condition_cmd\s*=\s*!\s*systemd-ac-power/.test(block);
            result[kind][battery ? "battery" : "ac"] = timeout;
        }
        return result;
    }

    function generate(): string {
        const actions = {
            lock: { run: "loginctl lock-session", name: "Lock" },
            screen: { run: `hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'`, resume: `hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'`, name: "Screen off" },
            suspend: { run: "systemctl suspend", name: "Suspend" }
        };
        const lines = [
            "# Idle timeouts set in Quickshell's settings window (Power and idle). hypridle runs",
            "# with this file instead of hypridle.conf while it exists; delete it (or reset the",
            "# timeouts in settings) to go back to hypridle.conf. This machine's own, not in the repo.",
            "",
            root.generalBlock,
            ""
        ];
        for (const kind of kinds) {
            for (const power of ["battery", "ac"]) {
                const seconds = get(kind, power);
                if (seconds <= 0)
                    continue;
                const action = actions[kind];
                lines.push(`# ${action.name} after ${seconds / 60} minutes ${power === "battery" ? "on battery" : "plugged in"}`);
                lines.push("listener {");
                lines.push(`    timeout = ${seconds}`);
                // Checked each minute, so plugging in or out while idle is noticed
                lines.push(`    condition_cmd = ${power === "battery" ? "! " : ""}systemd-ac-power`);
                lines.push("    condition_retry = 60");
                lines.push(`    on-timeout = ${action.run}`);
                if (action.resume)
                    lines.push(`    on-resume = ${action.resume}`);
                lines.push("}", "");
            }
        }
        return lines.join("\n");
    }

    FileView {
        id: defaultFile
        path: root.defaultPath
        printErrors: false
        onLoaded: {
            root.defaults = root.parse(text());
            root.generalBlock = text().match(/^general\s*\{[\s\S]*?^\}/m)?.[0] ?? "";
            if (!root.hasLocal)
                root.values = root.defaults;
            root.loaded = true;
        }
    }

    FileView {
        id: localFile
        path: root.localPath
        printErrors: false
        onLoaded: {
            root.hasLocal = true;
            root.values = root.parse(text());
        }
        onLoadFailed: root.hasLocal = false
    }

    Process {
        id: restart
    }
}

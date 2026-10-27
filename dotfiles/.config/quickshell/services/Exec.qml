pragma Singleton

import Quickshell

Singleton {
    // Locks the session, with hyprlock if the shell can't (hypr/scripts/lock). Not
    // `loginctl lock-session`, which only locks while hypridle is running.
    readonly property string lockCommand: "~/.config/hypr/scripts/lock"

    // Run through a shell so `~`, quoting and `||` work as on the command line
    function run(command: string): void {
        Quickshell.execDetached(["sh", "-c", command]);
    }

    // Start a shell command through Hyprland, so it isn't a child of the shell (restarting
    // qs leaves it running) and Hyprland's exec rules apply. `options` is a Lua table or "".
    function viaHyprland(command: string, options: string): void {
        const extra = options !== "" ? `, ${options}` : "";
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.exec_cmd(${lua(command)}${extra})`]);
    }

    // Open an app as a centred floating window, optionally at half the monitor size
    function floating(command: string, halfSize: bool): void {
        const size = halfSize ? `, size = { "monitor_w*0.5", "monitor_h*0.5" }` : "";
        viaHyprland(command, `{ float = true, center = true${size} }`);
    }

    // Quote an argument for sh
    function quote(arg: string): string {
        return `'${arg.replace(/'/g, "'\\''")}'`;
    }

    // A Lua string literal, for Hyprland's Lua (hyprctl eval, its config files): quotes,
    // backslashes and line breaks escaped (e.g. drive labels, theme names)
    function lua(text: string): string {
        return `"${text.replace(/[\\"]/g, "\\$&").replace(/\n/g, "\\n").replace(/\r/g, "\\r")}"`;
    }
}

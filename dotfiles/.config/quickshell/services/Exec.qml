pragma Singleton

import Quickshell

Singleton {
    // Run through a shell so `~`, quoting and `||` work like Waybar's commands
    function run(command: string): void {
        Quickshell.execDetached(["sh", "-c", command]);
    }

    // Start a shell command through Hyprland, so it isn't a child of the shell (restarting
    // qs leaves it running) and Hyprland's exec rules apply. `options` is a Lua table or "".
    function viaHyprland(command: string, options: string): void {
        // The command goes inside a Lua string, so escape quotes and backslashes (e.g. drive labels)
        const escaped = command.replace(/[\\"]/g, "\\$&");
        const extra = options !== "" ? `, ${options}` : "";
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.exec_cmd("${escaped}"${extra})`]);
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
}

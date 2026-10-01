pragma Singleton

import Quickshell

Singleton {
    // Run through a shell so `~`, quoting and `||` work like Waybar's commands
    function run(command: string): void {
        Quickshell.execDetached(["sh", "-c", command]);
    }

    // Open an app as a centred floating window, optionally at half the monitor size
    function floating(command: string, halfSize: bool): void {
        const size = halfSize ? `, size = { "monitor_w*0.5", "monitor_h*0.5" }` : "";
        // The command goes inside a Lua string, so escape quotes and backslashes (e.g. drive labels)
        const escaped = command.replace(/[\\"]/g, "\\$&");
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.exec_cmd("${escaped}", { float = true, center = true${size} })`]);
    }
}

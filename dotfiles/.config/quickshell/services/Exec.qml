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
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.exec_cmd("${command}", { float = true, center = true${size} })`]);
    }
}

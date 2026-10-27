pragma Singleton

import Quickshell
import Quickshell.Hyprland

Singleton {
    // Power actions, the same wherever they're started (the power menu, the lid, a low battery,
    // the lock screen):
    // - lock: with hyprlock if the shell can't (hypr/scripts/lock); not `loginctl lock-session`,
    //   which only locks while hypridle is running
    // - sleep: hibernating later where the machine can, otherwise just suspending
    // - suspend: locked first (hypridle locks before sleep, but only while it's running)
    // - log out, reboot and power off: through hyprshutdown, so apps close properly
    readonly property string lockCommand: "~/.config/hypr/scripts/lock"
    readonly property string sleepCommand: "systemctl suspend-then-hibernate || systemctl suspend"
    readonly property string suspendCommand: `${lockCommand}; ${sleepCommand}`
    readonly property string logoutCommand: "hyprshutdown -t 'Logging out...'"
    readonly property string rebootCommand: "hyprshutdown -t 'Rebooting...' --post-cmd 'systemctl reboot'"
    readonly property string powerOffCommand: "hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff'"

    function lock(): void {
        run(lockCommand);
    }

    function suspend(): void {
        run(suspendCommand);
    }

    function powerOff(): void {
        run(powerOffCommand);
    }

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

    // A workspace for Hyprland's Lua by its id, or by name for named ones (negative ids), so a
    // negative number can't be taken for a relative move ("-1" is the previous workspace)
    function workspace(id: int): string {
        if (id >= 1)
            return String(id);
        const name = Hyprland.workspaces.values.find(ws => ws.id === id)?.name ?? String(id);
        return lua(`name:${name}`);
    }

    // A Lua string literal, for Hyprland's Lua (hyprctl eval, its config files): quotes,
    // backslashes and line breaks escaped (e.g. drive labels, theme names)
    function lua(text: string): string {
        return `"${text.replace(/[\\"]/g, "\\$&").replace(/\n/g, "\\n").replace(/\r/g, "\\r")}"`;
    }
}

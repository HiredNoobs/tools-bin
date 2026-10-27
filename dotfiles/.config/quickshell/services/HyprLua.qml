pragma Singleton

import QtQuick
import Quickshell

// Hyprland's Lua through `hyprctl eval`, one call at a time and in order across the shell (a
// monitor change, an input setting and an overview drop never interleave). `done(ok, output)`:
// hyprctl prints "ok" (or nothing), or the Lua error.
Singleton {
    function run(code: string, done: var): void {
        queue.enqueue({
            command: ["hyprctl", "eval", code],
            done: (exitCode, stdout) => {
                const output = stdout.trim();
                done?.(exitCode >= 0 && (output === "ok" || output === ""), output);
            }
        });
    }

    ProcessQueue {
        id: queue
    }
}

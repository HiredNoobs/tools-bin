pragma Singleton

import QtQuick
import Quickshell

// The wallpaper: ~/.cache/current-wallpaper, a copy of the one picked in the wallpaper menu,
// drawn by wallpaper/Background.qml (also hyprlock's, and shared with the login screen).
// The path never changes, so `source` carries a version that goes up with each change, making
// images showing it load it again.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
    property int version: 0
    readonly property url source: `file://${path}?v=${version}`

    // Copied beside it first, then moved over it, so nothing reads half a picture. One picked
    // while the last is still being copied goes next (the newest wins).
    function set(file: string): void {
        copy.enqueue({
            command: ["sh", "-c", `cp -L "$1" "$2.new" && mv "$2.new" "$2"`, "sh", file, path],
            started: () => LockShare.shareWallpaper(file),
            done: code => {
                if (code === 0)
                    root.version++;
            }
        });
    }

    ProcessQueue {
        id: copy
        latestOnly: true
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper: ~/.cache/current-wallpaper, a copy of the one picked in the wallpaper menu,
// drawn by wallpaper/Background.qml (also hyprlock's, and shared with the login screen).
// The path never changes, so `source` carries a version that goes up with each change, making
// images showing it load it again.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
    property int version: 0
    readonly property url source: `file://${path}?v=${version}`

    // Copied beside it first, then moved over it, so nothing reads half a picture
    function set(file: string): void {
        copy.command = ["sh", "-c", `cp -L ${Exec.quote(file)} "$1.new" && mv "$1.new" "$1"`, "sh", path];
        copy.running = true;
        LockShare.shareWallpaper(file);
    }

    Process {
        id: copy
        onExited: code => {
            if (code === 0)
                root.version++;
        }
    }
}

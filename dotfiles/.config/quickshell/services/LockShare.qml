pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the login screen (the SDDM theme) showing what the lockscreen shows: the wallpaper,
// pywal's colours and the avatar, copied into a folder the user owns and the sddm user can read
// (made by setup; nothing happens without it). Copied when they change here, and all of them when
// the shell starts, in case they changed elsewhere. Each copy replaces the file in one go, so the
// greeter never reads half of one.
// Also the avatar: ~/.face, a link to the picture chosen in Settings › Appearance.
Singleton {
    id: root

    readonly property string dir: "/var/lib/quickshell-lock"
    readonly property string home: Quickshell.env("HOME")
    readonly property string facePath: `${home}/.face`
    // Pictures offered as avatars
    readonly property string facesFolder: `${home}/Pictures/profile-pictures`

    // Whether setup made the folder (so the login screen follows)
    property bool shared: false
    // What ~/.face points at, and the pictures to choose from
    property string face: ""
    property var faces: []

    // `name` within the folder, e.g. "faces/<user>"; copied beside it first, then moved over it
    function copy(source: string, name: string): void {
        const temporary = `${dir}/.${name.replace(/\//g, "-")}.new`;
        Exec.run(`[ -w ${dir} ] && cp -L ${Exec.quote(source)} ${temporary} && mv ${temporary} ${dir}/${name}`);
    }

    function shareWallpaper(source: string): void {
        copy(source, "wallpaper");
    }

    function shareAll(): void {
        copy(`${home}/.cache/current-wallpaper`, "wallpaper");
        copy(`${home}/.cache/wal/colors.json`, "colors.json");
        copy(facePath, `faces/${Quickshell.env("USER")}`);
    }

    // The avatar, for the lockscreen, hyprlock and (shared) the login screen
    function setFace(path: string): void {
        Exec.run(`ln -sfn ${Exec.quote(path)} ${Exec.quote(facePath)}`);
        copy(path, `faces/${Quickshell.env("USER")}`);
        face = path;
    }

    function refresh(): void {
        scan.running = true;
    }

    Component.onCompleted: {
        shareAll();
        refresh();
    }

    // "shared" if the folder is writable, "face<TAB>path" for ~/.face, "pic<TAB>path" per picture
    Process {
        id: scan
        command: ["sh", "-c", `
            [ -w ${root.dir} ] && echo shared
            printf 'face\\t%s\\n' "$(readlink -f ${Exec.quote(root.facePath)})"
            find ${Exec.quote(root.facesFolder)} -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf 'pic\\t%p\\n' 2>/dev/null | sort
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const faces = [];
                let shared = false;
                for (const line of text.split("\n")) {
                    const [kind, path] = line.split("\t");
                    if (kind === "shared")
                        shared = true;
                    else if (kind === "face")
                        root.face = path ?? "";
                    else if (kind === "pic" && path)
                        faces.push(path);
                }
                root.shared = shared;
                root.faces = faces;
            }
        }
    }

    // pywal's colours change: the login screen's too
    FileView {
        path: `${root.home}/.cache/wal/colors.json`
        watchChanges: true
        printErrors: false
        onFileChanged: root.copy(path, "colors.json")
    }
}

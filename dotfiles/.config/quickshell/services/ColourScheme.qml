pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The colour scheme, in pywal's files in ~/.cache/wal (pywal itself isn't used): colors.json
// for the shell (Theme), the lock and login screens and the window borders, colors-kitty.conf
// for kitty and colors-hyprland.conf for hyprlock. Either the fixed Gruvbox set or one made from
// the wallpaper (ShellSettings.colourSource), written again when either changes; kitty and the
// borders are told straight away, the rest watch the files.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.cache/wal"
    readonly property bool fromWallpaper: ShellSettings.colourSource === "wallpaper"

    // { background, foreground, colors: [16 hex strings] }
    readonly property var fixed: ({
            background: "#282828",
            foreground: "#d5c4a1",
            colors: ["#282828", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#d5c4a1",
                "#665c54", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#fbf1c7"]
        })
    readonly property var current: fromWallpaper ? fromColours(quantizer.colors) : fixed

    onCurrentChanged: write.restart()
    Component.onCompleted: write.restart()

    // The wallpaper's main colours (16 of them)
    ColorQuantizer {
        id: quantizer
        source: root.fromWallpaper ? Wallpaper.source : ""
        depth: 4
        rescaleSize: 128
    }

    // Together, in case the source and the colours change one after the other
    Timer {
        id: write
        interval: 200
        onTriggered: root.save(root.current)
    }

    function hex(colour: color): string {
        return colour.toString().slice(0, 7);
    }

    // A scheme from the wallpaper's colours: a dark background and light text tinted with its
    // darkest colour, the most vivid one (made brighter) as the accent, and the next most vivid,
    // spread around the colour wheel, for the terminal's other colours
    function fromColours(colours): var {
        if (!colours || colours.length === 0)
            return null;
        const all = Array.from(colours).map(c => ({ h: Math.max(0, c.hslHue), s: c.hslSaturation, l: c.hslLightness }));
        const darkest = all.reduce((a, b) => b.l < a.l ? b : a);
        const vividness = c => c.s * (1 - Math.abs(c.l - 0.55));
        const vivid = all.filter(c => c.s > 0.15).sort((a, b) => vividness(b) - vividness(a));
        const accentHue = vivid.length > 0 ? vivid[0].h : 0.02;
        const accentSaturation = vivid.length > 0 ? Math.max(0.6, vivid[0].s) : 0.9;

        // Up to five more hues, each well apart from the ones before; the accent's, turned, fill
        // any gaps
        const hues = [accentHue];
        for (const c of vivid) {
            if (hues.length === 6)
                break;
            if (hues.every(h => Math.min(Math.abs(h - c.h), 1 - Math.abs(h - c.h)) > 0.08))
                hues.push(c.h);
        }
        for (let turn = 1; hues.length < 6; turn++)
            hues.push((accentHue + turn / 6) % 1);

        const tint = darkest.s > 0.05 ? darkest.h : accentHue;
        const background = Qt.hsla(tint, Math.min(darkest.s, 0.3), 0.11, 1);
        const foreground = Qt.hsla(tint, 0.25, 0.82, 1);
        const accent = Qt.hsla(accentHue, accentSaturation, 0.6, 1);
        const others = hues.slice(1).map(h => Qt.hsla(h, Math.max(0.45, accentSaturation * 0.8), 0.65, 1));
        const normal = [background, accent, ...others, foreground].map(root.hex);
        return {
            background: root.hex(background),
            foreground: root.hex(foreground),
            colors: [...normal.slice(0, 7), root.hex(foreground), root.hex(Qt.hsla(tint, 0.15, 0.38, 1)), ...normal.slice(1, 7), root.hex(Qt.hsla(tint, 0.3, 0.93, 1))]
        };
    }

    // "rgba(r,g,b,a)" for Hyprland's configs
    function rgba(hexColour: string, alpha: real): string {
        const c = Qt.color(hexColour);
        return `rgba(${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)},${alpha})`;
    }

    function save(scheme): void {
        if (!scheme)
            return;
        const c = scheme.colors;
        const colours = {};
        c.forEach((value, i) => colours[`color${i}`] = value);
        const json = JSON.stringify({
            wallpaper: root.fromWallpaper ? Wallpaper.path : "None",
            alpha: "100",
            special: { background: scheme.background, foreground: scheme.foreground, cursor: scheme.foreground },
            colors: colours
        }, null, 4) + "\n";
        // Unchanged: leave the files (and everything watching them) alone
        if (json === existing.text())
            return;

        const kitty = [
            `foreground ${scheme.foreground}`, `background ${scheme.background}`, "background_opacity 1.0", `cursor ${scheme.foreground}`, "",
            `active_tab_foreground ${scheme.background}`, `active_tab_background ${scheme.foreground}`,
            `inactive_tab_foreground ${scheme.foreground}`, `inactive_tab_background ${scheme.background}`, "",
            `active_border_color ${scheme.foreground}`, `inactive_border_color ${scheme.background}`, `bell_border_color ${c[1]}`, "",
            ...c.map((value, i) => `color${i} ${value}`)
        ].join("\n") + "\n";

        // hyprlock's, with the alpha versions of Theme's colours its layout uses ($subtextMarkup
        // goes in Pango markup, where "##" is how hyprlock writes "#")
        const hyprland = [
            `$foreground = ${rgba(scheme.foreground, 1.0)}`, `$background = ${rgba(scheme.background, 1.0)}`,
            ...c.map((value, i) => `$color${i} = ${rgba(value, 1.0)}`), "",
            `$accent = ${rgba(c[9], 1.0)}`, `$card = ${rgba(scheme.background, 0.97)}`,
            `$surface = ${rgba(scheme.foreground, 0.08)}`, `$subtext = ${rgba(scheme.foreground, 0.6)}`,
            `$subtextMarkup = ##${scheme.foreground.slice(1)}99`
        ].join("\n") + "\n";

        saver.command = ["sh", "-c", `
            mkdir -p "$1" &&
            printf '%s' "$2" > "$1/.colors-kitty.conf.new" && mv "$1/.colors-kitty.conf.new" "$1/colors-kitty.conf" &&
            printf '%s' "$3" > "$1/.colors-hyprland.conf.new" && mv "$1/.colors-hyprland.conf.new" "$1/colors-hyprland.conf" &&
            printf '%s' "$4" > "$1/.colors.json.new" && mv "$1/.colors.json.new" "$1/colors.json" &&
            pkill -USR1 -x kitty
            hyprctl eval "hl.config({ general = { col = { active_border = \\"$5\\", inactive_border = \\"$6\\" } } })" >/dev/null
        `, "sh", root.dir, kitty, hyprland, json, rgba(c[9], 1), rgba(c[5], 1)];
        saver.running = true;
    }

    Process {
        id: saver
    }

    FileView {
        id: existing
        path: `${root.dir}/colors.json`
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
}

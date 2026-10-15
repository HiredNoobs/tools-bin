pragma Singleton

import QtQuick
import Quickshell
import qs

// Ready-made looks for Settings › Appearance: a colour scheme (ColourScheme) with the dark or
// light mode, Qt (Kvantum) theme and icons that suit it, applied in one go through Appearance,
// so the lock and login screens follow too. With ShellSettings.presetCursors, a cursor too
// (at the current size); otherwise it stays as it is, like the fonts and wallpaper. Themes
// that aren't installed are skipped. The icons go last, as changing them restarts the shell.
Singleton {
    id: root

    readonly property var presets: [
        { label: "Gruvbox", colours: "gruvbox", dark: true, kvantum: "KvDark", icons: "Papirus-Dark", cursor: "capitaine-cursors" },
        { label: "Nord", colours: "nord", dark: true, kvantum: "KvArcDark", icons: "Papirus-Dark", cursor: "catppuccin-frappe-blue-cursors" },
        { label: "Catppuccin", colours: "catppuccin", dark: true, kvantum: "KvDark", icons: "Papirus-Dark", cursor: "catppuccin-mocha-mauve-cursors" },
        { label: "Tokyo Night", colours: "tokyo-night", dark: true, kvantum: "KvArcDark", icons: "Papirus-Dark", cursor: "catppuccin-frappe-blue-cursors" },
        { label: "Rosé Pine", colours: "rose-pine", dark: true, kvantum: "KvDark", icons: "Papirus-Dark", cursor: "catppuccin-mocha-mauve-cursors" },
        { label: "Everforest", colours: "everforest", dark: true, kvantum: "KvDark", icons: "Papirus-Dark", cursor: "capitaine-cursors" },
        { label: "Gruvbox Light", colours: "gruvbox-light", dark: false, kvantum: "KvFlatLight", icons: "Papirus-Light", cursor: "capitaine-cursors-light" },
        { label: "Catppuccin Latte", colours: "catppuccin-latte", dark: false, kvantum: "KvFlatLight", icons: "Papirus-Light", cursor: "catppuccin-latte-mauve-cursors" },
        { label: "Wallpaper", colours: "wallpaper", dark: true, kvantum: "KvDark", icons: "Papirus-Dark", cursor: "" }
    ]

    function apply(preset): void {
        // Also picks the GTK theme's dark or light version
        Appearance.setDark(preset.dark);
        if (Appearance.kvantumThemes.includes(preset.kvantum))
            Appearance.setKvantumTheme(preset.kvantum);
        ShellSettings.colourSource = preset.colours;
        if (usesCursor(preset) && preset.cursor !== Appearance.cursorTheme)
            Appearance.setCursor(preset.cursor, Appearance.cursorSize);
        if (Appearance.iconThemes.includes(preset.icons) && preset.icons !== Appearance.iconTheme)
            Appearance.setIconTheme(preset.icons);
    }

    function usesCursor(preset): bool {
        return ShellSettings.presetCursors && preset.cursor !== "" && Appearance.cursorThemes.includes(preset.cursor);
    }

    // Everything it sets is as it set it (themes it would skip don't count)
    function isCurrent(preset): bool {
        return ShellSettings.colourSource === preset.colours
            && Appearance.dark === preset.dark
            && (!Appearance.kvantumThemes.includes(preset.kvantum) || Appearance.kvantumTheme === preset.kvantum)
            && (!Appearance.iconThemes.includes(preset.icons) || Appearance.iconTheme === preset.icons)
            && (!usesCursor(preset) || Appearance.cursorTheme === preset.cursor);
    }
}

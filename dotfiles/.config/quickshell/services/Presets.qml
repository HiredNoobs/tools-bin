pragma Singleton

import QtQuick
import Quickshell
import qs

// Ready-made looks for Settings › Appearance: a colour scheme (ColourScheme) with the dark or
// light mode, Qt (Kvantum) theme and icons that suit it, applied in one go through Appearance,
// so the lock and login screens follow too. Fonts, cursor and wallpaper stay as they are, and
// themes that aren't installed are skipped. The icons go last, as changing them restarts the
// shell.
Singleton {
    id: root

    readonly property var presets: [
        { label: "Gruvbox", colours: "gruvbox", dark: true, kvantum: "KvDark", icons: "Papirus-Dark" },
        { label: "Nord", colours: "nord", dark: true, kvantum: "KvArcDark", icons: "Papirus-Dark" },
        { label: "Catppuccin", colours: "catppuccin", dark: true, kvantum: "KvDark", icons: "Papirus-Dark" },
        { label: "Gruvbox Light", colours: "gruvbox-light", dark: false, kvantum: "KvFlatLight", icons: "Papirus-Light" },
        { label: "Wallpaper", colours: "wallpaper", dark: true, kvantum: "KvDark", icons: "Papirus-Dark" }
    ]

    function apply(preset): void {
        // Also picks the GTK theme's dark or light version
        Appearance.setDark(preset.dark);
        if (Appearance.kvantumThemes.includes(preset.kvantum))
            Appearance.setKvantumTheme(preset.kvantum);
        ShellSettings.colourSource = preset.colours;
        if (Appearance.iconThemes.includes(preset.icons) && preset.icons !== Appearance.iconTheme)
            Appearance.setIconTheme(preset.icons);
    }

    // Everything it sets is as it set it (themes it would skip don't count)
    function isCurrent(preset): bool {
        return ShellSettings.colourSource === preset.colours
            && Appearance.dark === preset.dark
            && (!Appearance.kvantumThemes.includes(preset.kvantum) || Appearance.kvantumTheme === preset.kvantum)
            && (!Appearance.iconThemes.includes(preset.icons) || Appearance.iconTheme === preset.icons);
    }
}

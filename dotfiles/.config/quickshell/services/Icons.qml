pragma Singleton

import QtQuick
import Quickshell

// Icons for apps and notifications, from whatever names they come with: a file path, an icon
// theme name, "image://icon/<name>" (udiskie sends those) or another image URL. "" when none
// resolves, rather than the placeholder texture.
Singleton {
    // The first of `names` that resolves (empty ones are skipped)
    function resolve(names: var): string {
        for (let name of names) {
            if (!name)
                continue;
            if (name.startsWith("/"))
                return `file://${name}`;
            // Theme names in a URL still need checking, or a missing one draws the placeholder
            if (name.startsWith("image://icon/"))
                name = name.slice("image://icon/".length);
            else if (name.includes("://"))
                return name;
            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
        }
        return "";
    }

    // An app by its Wayland app id or window class, through its desktop entry if it has one
    function forApp(appId: string): string {
        // Re-run once desktop entries have loaded, so icons resolve
        DesktopEntries.applications.values.length;
        return resolve([DesktopEntries.heuristicLookup(appId)?.icon ?? "", appId]);
    }
}

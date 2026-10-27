pragma Singleton

import QtQuick
import Quickshell

// How often and how recently each app was started from the launcher, so the ones in use come
// first. Stored in the shell's state directory as { "<desktop id>": { count, last } }.
Singleton {
    id: root

    property var usage: ({})

    // Saved once the file has been read (launches before that are added on to what it holds)
    function record(id: string): void {
        const entry = usage[id] ?? { count: 0, last: 0 };
        const updated = Object.assign({}, usage);
        updated[id] = { count: entry.count + 1, last: Date.now() };
        usage = updated;
        file.save(usage);
    }

    // Launch count weighted by how recently it was last used; 0 if never used
    function score(id: string): real {
        const entry = usage[id];
        if (!entry)
            return 0;
        const days = (Date.now() - entry.last) / 86400000;
        const weight = days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : 0.5;
        return entry.count * weight;
    }

    JsonFile {
        id: file
        path: Quickshell.statePath("launcher.json")
        // With anything recorded before it was read added on
        onRead: stored => {
            const merged = Object.assign({}, stored);
            for (const id in root.usage) {
                const before = stored[id] ?? { count: 0, last: 0 };
                merged[id] = { count: before.count + root.usage[id].count, last: Math.max(before.last, root.usage[id].last) };
            }
            const recorded = Object.keys(root.usage).length > 0;
            root.usage = merged;
            if (recorded)
                file.save(merged);
        }
    }
}

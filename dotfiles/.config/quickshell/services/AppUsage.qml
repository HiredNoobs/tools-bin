pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How often and how recently each app was started from the launcher, so the ones in use come
// first. Stored in the shell's state directory as { "<desktop id>": { count, last } }.
Singleton {
    id: root

    property var usage: ({})
    // Read (or there's nothing to read), so writing won't replace what's there
    property bool loaded: false

    function record(id: string): void {
        const entry = usage[id] ?? { count: 0, last: 0 };
        const updated = Object.assign({}, usage);
        updated[id] = { count: entry.count + 1, last: Date.now() };
        usage = updated;
        if (loaded)
            file.setText(JSON.stringify(usage));
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

    FileView {
        id: file
        path: Quickshell.statePath("launcher.json")
        printErrors: false
        onLoaded: {
            try {
                // With anything recorded before it was read
                root.usage = Object.assign(JSON.parse(text()), root.usage);
            } catch (e) {
                root.usage = {};
            }
            root.loaded = true;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }
}

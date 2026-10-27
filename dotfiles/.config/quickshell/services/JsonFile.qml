import QtQuick
import Quickshell
import Quickshell.Io

// A JSON file in the shell's state folder (e.g. the notes). `read(stored)` gives what it holds
// once read: `fallback` if it doesn't exist yet, is empty, or can't be parsed, in which case
// it's first kept aside as <path>.broken-<time>, so nothing in it is lost. `save(value)` writes
// it, but never before it has been read (that would replace what's in it); one that couldn't be
// read for another reason (`failed`, e.g. permissions) is never written.
Scope {
    id: root

    required property string path
    property var fallback: ({})
    // Spaces to indent with (0 writes it on one line)
    property int indent: 0
    // Read before anything else happens (e.g. state needed at start)
    property bool blocking: false
    // What it holds: as last read or saved
    property var value: fallback
    property bool loaded: false
    property bool failed: false

    signal read(var stored)

    function save(newValue: var): bool {
        value = newValue;
        if (!loaded || failed)
            return false;
        file.setText(indent > 0 ? JSON.stringify(newValue, null, indent) : JSON.stringify(newValue));
        return true;
    }

    function received(stored: var): void {
        value = stored;
        loaded = true;
        root.read(stored);
    }

    FileView {
        id: file
        path: root.path
        blockLoading: root.blocking
        printErrors: false
        onLoaded: {
            const text = file.text();
            if (text.trim() === "") {
                root.received(root.fallback);
                return;
            }
            let stored;
            try {
                stored = JSON.parse(text);
            } catch (e) {
                // Written there straight away (not copied by a process), so a save right after
                // can't get in first
                const backupPath = `${root.path}.broken-${Date.now()}`;
                const backup = Qt.createQmlObject("import Quickshell.Io; FileView { preload: false; blockWrites: true; printErrors: false }", root);
                backup.path = backupPath;
                backup.setText(text);
                backup.destroy();
                console.warn(`${root.path} couldn't be read; kept as ${backupPath}`);
                stored = root.fallback;
            }
            root.received(stored);
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.received(root.fallback);
            else
                root.failed = true;
        }
    }
}

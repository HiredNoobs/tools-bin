pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Clipboard history for the Super+V menu, from `wl-paste --watch` (no cliphist). Kept in memory
// only, so it's gone when the shell restarts; pictures go to a folder in $XDG_RUNTIME_DIR
// (memory too, emptied at start). Copies a password manager marks as secret are never kept,
// nor (ShellSettings.clipboardSkipPasswords) text that looks like a password, as not every
// manager marks them (Bitwarden in Firefox doesn't). ShellSettings.clipboardHistory turns it
// off (and clears it).
Singleton {
    id: root

    readonly property bool enabled: ShellSettings.clipboardHistory
    readonly property int limit: 50
    // Longer text is kept cut short
    readonly property int maxBytes: 100000
    readonly property string imageDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-clipboard`

    // [{ text } or { image: path }], newest first
    property var entries: []
    // The latest copy wasn't kept (a secret, or text that looks like a password), so an app
    // emptying the clipboard next is clearing that, not entries[0]
    property bool skippedLast: false

    onEnabledChanged: {
        if (!enabled)
            clear();
    }

    // Switched on: forget what's kept already that it would have skipped
    readonly property bool skipPasswords: ShellSettings.clipboardSkipPasswords
    onSkipPasswordsChanged: {
        if (skipPasswords)
            entries = entries.filter(e => e.text === undefined || !looksLikePassword(e.text));
    }

    // Puts an entry back on the clipboard (which also moves it to the top). Text goes to
    // wl-copy on stdin, as anyone can read a command line while it runs.
    function copy(entry): void {
        if (entry.image) {
            Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "$1"`, "sh", entry.image]);
            return;
        }
        copier.queued = entry.text;
        if (!copier.running)
            copier.next();
    }

    // A picture the watcher below saved: in imageDir, named after its contents. Anything else
    // is ignored, so a forged record can't point it at another file to copy or delete.
    function isSavedImage(path: string): bool {
        return path.startsWith(imageDir + "/") && /^[0-9a-f]{40}\.png$/.test(path.slice(imageDir.length + 1));
    }

    // Entries match by what's in them: the menu's rows hold copies, not these objects
    function same(a, b): bool {
        return a.text !== undefined ? a.text === b.text : a.image === b.image;
    }

    // One line, no spaces, 8-128 characters, and at least three of lower case, upper case,
    // digits and symbols: generated passwords, API keys and tokens (secret too). Not links,
    // email addresses or paths, and - _ . don't count as symbols, so names like "Papirus-Dark"
    // or "HDMI-A-1" are kept. Short code (brackets, quotes, =, commas) is kept too; with those,
    // only 16+ characters using all four kinds count, as some sites' passwords use them. Whitespace and NULs at the
    // ends, which some apps add when they copy, are ignored.
    function looksLikePassword(copied: string): bool {
        const text = copied.replace(/^[\s\u0000]+|[\s\u0000]+$/g, "");
        if (text.length < 8 || text.length > 128 || /\s/.test(text))
            return false;
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(text) || /^[^@]+@[^@]+\.[a-z]+$/i.test(text) || /^[~.]?\//.test(text))
            return false;
        const kinds = [/[a-z]/, /[A-Z]/, /[0-9]/, /[^a-zA-Z0-9._-]/].filter(kind => kind.test(text)).length;
        // A function call ("name.name(…)") is code whatever else is in it
        if (/[()\[\]{}<>"'`,;=]/.test(text))
            return text.length >= 16 && kinds === 4 && !/^[A-Za-z_$][\w$.]*\(.*\)$/.test(text);
        return kinds >= 3;
    }

    // An app emptied the clipboard on purpose (e.g. Bitwarden's "Clear clipboard after…"):
    // forget what it held, as that's usually why, unless that copy was never kept
    function forgetNewest(): void {
        if (skippedLast)
            skippedLast = false;
        else if (entries.length > 0)
            remove(entries[0]);
    }

    function remove(entry): void {
        entries = entries.filter(e => !same(e, entry));
        if (entry.image)
            Quickshell.execDetached(["rm", "-f", entry.image]);
    }

    function clear(): void {
        entries = [];
        Quickshell.execDetached(["sh", "-c", `rm -f "$1"/*.png`, "sh", imageDir]);
    }

    function add(entry): void {
        if (entry.text !== undefined && ShellSettings.clipboardSkipPasswords && looksLikePassword(entry.text)) {
            skippedLast = true;
            return;
        }
        skippedLast = false;
        // The same text, or the same picture (named after its contents)
        const kept = entries.filter(e => !same(e, entry));
        for (const old of kept.slice(limit - 1))
            if (old.image)
                Quickshell.execDetached(["rm", "-f", old.image]);
        entries = [entry, ...kept.slice(0, limit - 1)];
    }

    // Each change: "T<TAB>text", "I<TAB>path" or "S<TAB>" (a secret copy, CLIPBOARD_STATE=
    // sensitive, not kept), ended by a record separator (\x1e). A clipboard emptied by its app
    // closing prints nothing (an app writing empty text does: see forgetNewest); a picture is
    // kept as a picture only when no text came with it, named after its contents so a repeat is
    // the same file. Other copies with no text (e.g. JPEG only) aren't kept. Copied text can't
    // contain the separator (it's taken out), so it can't pass for more records.
    Process {
        running: root.enabled
        // The watcher runs until the shell exits (tail --pid; killing qs would orphan it
        // otherwise) or this is stopped
        command: ["sh", "-c", `rm -rf "$1" && mkdir -p -m 700 "$1" || exit 1
        wl-paste --watch sh -c '
            cat >/dev/null
            [ "$CLIPBOARD_STATE" = sensitive ] && { printf "S\\t\\036"; exit 0; }
            [ "$CLIPBOARD_STATE" = data ] || exit 0
            types=$(wl-paste --list-types)
            if printf "%s\\n" "$types" | grep -q "^image/png$" && ! printf "%s\\n" "$types" | grep -q "^text/plain"; then
                file="$0/$(wl-paste --type image/png | sha1sum | cut -c1-40).png"
                { [ -e "$file" ] || wl-paste --type image/png > "$file"; } && printf "I\\t%s\\036" "$file"
            elif printf "%s\\n" "$types" | grep -qE "^(text/|UTF8_STRING$|STRING$|TEXT$)"; then
                printf "T\\t"; wl-paste --type text --no-newline | tr -d "\\036" | head -c ${root.maxBytes}; printf "\\036"
            fi
        ' "$1" &
        watcher=$!
        trap 'kill $watcher 2>/dev/null' EXIT TERM INT
        tail --pid=$PPID -f /dev/null &
        wait $!`, "sh", root.imageDir]
        stdout: SplitParser {
            splitMarker: "\u001e"
            onRead: data => {
                const tab = data.indexOf("\t");
                const kind = data.slice(0, tab);
                const value = data.slice(tab + 1);
                if (kind === "S")
                    root.skippedLast = true;
                else if (kind === "T" && value.replace(/[\s\u0000]/g, "") === "")
                    root.forgetNewest();
                else if (kind === "T")
                    // Without a character cut in half by maxBytes (decoded as U+FFFD)
                    root.add({ text: value.replace(/\uFFFD+$/, "") });
                else if (kind === "I" && root.isSavedImage(value))
                    root.add({ image: value });
            }
        }
    }

    // Text going back on the clipboard; the newest waits if one is still being handed over
    Process {
        id: copier

        // Text waiting to go (null when none), and the text going now
        property var queued: null
        property string text

        function next(): void {
            text = queued;
            queued = null;
            running = true;
        }

        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: {
            write(text);
            text = "";
            stdinEnabled = false;
        }
        onExited: {
            stdinEnabled = true;
            if (queued !== null)
                next();
        }
    }
}

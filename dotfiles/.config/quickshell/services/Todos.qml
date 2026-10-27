pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Notes for the calendar panel, saved in Quickshell's local state folder (not in the repo,
// not synced between machines).
// Dated notes belong to a day and carry forward as overdue until ticked off; ongoing notes
// have no date. Ticked notes stay (struck through) for the rest of the day, then go.
Singleton {
    id: root

    // [{ id, text, date: "yyyy-MM-dd" | null, done, doneOn: "yyyy-MM-dd" | null }]
    property var items: []
    property bool loaded: false
    // The file is there but couldn't be read (not just missing): nothing can be added, as it
    // couldn't be saved
    property bool loadFailed: false

    readonly property string path: Quickshell.statePath("todos.json")
    readonly property string today: dayKey(clock.date)

    function dayKey(date: date): string {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    // Notes on a day (yyyy-MM-dd). Today also gets open notes from earlier days (overdue).
    function forDay(day: string): var {
        return items.filter(item => item.date === day || (day === today && item.date && item.date < today && !item.done));
    }

    readonly property var ongoing: items.filter(item => !item.date)

    // Days that have open notes, for the calendar's dots
    readonly property var busyDays: {
        const days = {};
        for (const item of items) {
            if (item.date && !item.done)
                days[item.date] = true;
        }
        return days;
    }

    function add(text: string, day: string): void {
        const trimmed = text.trim();
        if (trimmed === "" || !loaded)
            return;
        items = [...items, { id: Date.now(), text: trimmed, date: day || null, done: false, doneOn: null }];
        save();
    }

    function toggle(id: real): void {
        items = items.map(item => item.id !== id ? item : Object.assign({}, item, { done: !item.done, doneOn: item.done ? null : today }));
        save();
    }

    function remove(id: real): void {
        items = items.filter(item => item.id !== id);
        save();
    }

    // Ticked notes from before today go
    function tidy(): void {
        const kept = items.filter(item => !item.done || item.doneOn === today);
        if (kept.length !== items.length) {
            items = kept;
            save();
        }
    }

    // Never before the file has been read, which would replace the notes in it
    function save(): void {
        if (loaded)
            file.setText(JSON.stringify(items, null, 2));
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // The state folder doesn't exist until something is saved there
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", path.slice(0, path.lastIndexOf("/"))])

    // A new day: clear yesterday's ticked notes
    onTodayChanged: {
        if (loaded)
            tidy();
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        onLoaded: {
            try {
                root.items = JSON.parse(text());
            } catch (e) {
                // Unreadable: kept aside before starting again, so the notes can be recovered
                Quickshell.execDetached(["cp", root.path, `${root.path}.broken-${Date.now()}`]);
                root.items = [];
            }
            root.loaded = true;
            root.tidy();
        }
        // No file yet: start empty. Any other error leaves it alone (and saving off)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.loaded = true;
            else
                root.loadFailed = true;
        }
    }
}

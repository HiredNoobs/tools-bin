import QtQuick
import Quickshell
import Quickshell.Io

// Runs commands one at a time, in order: a request made while one is still running waits its
// turn instead of being dropped. With `latestOnly`, only the newest waiting request is kept (the
// last wallpaper picked, the last scheme). A job is
// { command, input?, started?(), done?(code, stdout, stderr) }:
// - `input` is written to its stdin (for secrets: a command line can be read by any user while
//   it runs), and forgotten once written; stdin is closed either way, so nothing waits on it
// - `started` runs just before it starts (e.g. to write a file it reads)
// - `done` runs once, after it has exited and its output is in; a command that can't start
//   (not installed) ends with code -1
Scope {
    id: root

    property bool latestOnly: false
    // The job running now (null when none), and those waiting, oldest first
    property var current: null
    property var waiting: []
    readonly property bool busy: current !== null

    function enqueue(job: var): void {
        waiting = latestOnly ? [job] : [...waiting, job];
        next();
    }

    // The next waiting job won't run (e.g. the second step of a change whose first failed)
    function dropNext(): void {
        waiting = waiting.slice(1);
    }

    function clear(): void {
        waiting = [];
    }

    function next(): void {
        if (current || waiting.length === 0)
            return;
        const job = waiting[0];
        waiting = waiting.slice(1);
        current = job;
        job.started?.();
        process.code = -1;
        process.ran = false;
        process.input = job.input ?? "";
        job.input = "";
        process.stdinEnabled = true;
        process.command = job.command;
        process.running = true;
    }

    Process {
        id: process

        property int code: -1
        // Whether it started (the collectors keep the last run's output otherwise)
        property bool ran: false
        property string input

        // The input, if any, then end of input
        onStarted: {
            ran = true;
            if (input !== "")
                write(input);
            input = "";
            stdinEnabled = false;
        }
        onExited: exitCode => code = exitCode
        stdout: StdioCollector {
            id: output
        }
        stderr: StdioCollector {
            id: errors
        }
        // Streams finish, then it exits, then it stops running (or only that, if it couldn't
        // start); the next job starts once this one's `done` has run
        onRunningChanged: {
            if (running || !root.current)
                return;
            const job = root.current;
            input = "";
            root.current = null;
            job.done?.(code, ran ? output.text : "", ran ? errors.text : "");
            Qt.callLater(root.next);
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pending pacman updates for the system panel, from `checkupdates` (pacman-contrib), which
// syncs a private copy of the package databases so the real ones are left alone. Checked a
// minute after the shell starts and then every 3.5 hours; never pops anything up.
Singleton {
    id: root

    // [{ name, from, to }]
    property var packages: []
    // checkupdates is installed
    property bool available: false
    property bool checking: false
    // When the last check finished, or null; whether it failed (e.g. offline)
    property var lastChecked: null
    property bool failed: false

    // A check asked for before we know checkupdates is there (e.g. the IPC call that created
    // this singleton) runs once we do
    property bool pending: false

    function check(): void {
        if (!available)
            pending = true;
        else if (!checking)
            checker.running = true;
    }

    Process {
        command: ["sh", "-c", "command -v checkupdates"]
        running: true
        onExited: code => {
            root.available = code === 0;
            if (root.available && root.pending)
                root.check();
            root.pending = false;
        }
    }

    Timer {
        interval: 60000
        running: root.available
        onTriggered: root.check()
    }

    Timer {
        interval: 3.5 * 3600 * 1000
        running: root.available
        repeat: true
        onTriggered: root.check()
    }

    // The exit code goes on the last line, so it arrives with the output: 0 = updates listed,
    // 2 = none, anything else = it failed (e.g. offline), keeping the last list
    Process {
        id: checker
        command: ["sh", "-c", "checkupdates; echo \"exit $?\""]
        onRunningChanged: {
            if (running)
                root.checking = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const code = Number(lines.pop().replace("exit ", ""));
                root.checking = false;
                root.lastChecked = new Date();
                root.failed = code !== 0 && code !== 2;
                if (code === 2) {
                    root.packages = [];
                } else if (code === 0) {
                    root.packages = lines
                        .map(line => line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/))
                        .filter(match => match)
                        .map(match => ({ name: match[1], from: match[2], to: match[3] }));
                }
            }
        }
    }
}

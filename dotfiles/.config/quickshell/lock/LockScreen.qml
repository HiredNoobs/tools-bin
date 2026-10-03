import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs

// The lockscreen, in place of hyprlock: a session lock with one surface per screen (see
// LockContent), and the password checked through PAM (the `login` stack, as hyprlock used).
// The password typed is shared, so any screen can take it. `preview()` shows the same thing in
// an ordinary window, for trying it out without locking (unlocking there closes it; its power
// buttons do nothing).
// While locked, a flag in Quickshell's state folder makes a restarted shell lock again at
// once, taking over from the dead one (Hyprland's misc.allow_session_lock_restore), so a crash
// or `pkill qs` never leaves the session open. If the shell can't start at all: switch to a
// TTY and run `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`.
Scope {
    id: root

    property bool locked: false
    property bool previewing: false

    property string password: ""
    property bool busy: false
    // Shown under the password box, e.g. a wrong password
    property string message: ""
    // Bumped on each failure, for the box's shake
    property int failures: 0

    // The name the card greets: the account's full name, else the user name
    property string userName: Quickshell.env("USER")
    // On any keyboard, as Hyprland reports it (checked as keys are pressed)
    property bool capsLock: false

    // A moment after the key, so pressing Caps Lock itself has been counted
    function checkCaps(): void {
        capsDelay.restart();
    }

    function lock(): void {
        password = "";
        message = "";
        checkCaps();
        locked = true;
        flag.setText("locked\n");
    }

    function preview(): void {
        password = "";
        message = "";
        previewing = !previewing;
        checkCaps();
    }

    function submit(): void {
        if (busy || password === "")
            return;
        busy = true;
        message = "";
        if (!pam.start()) {
            busy = false;
            message = "Couldn't check the password";
        }
    }

    function unlocked(): void {
        password = "";
        message = "";
        lockedUntil = 0;
        if (locked) {
            locked = false;
            Quickshell.execDetached(["rm", "-f", flag.path]);
        }
        previewing = false;
    }

    PamContext {
        id: pam

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.unlocked();
                return;
            }
            root.password = "";
            root.failures++;
            root.message = "Wrong password";
            faillock.running = true;
        }

        onError: error => {
            root.busy = false;
            root.message = "Couldn't check the password";
        }
    }

    // --- pam_faillock: after `deny` failures within `fail_interval`, even the right password is
    // refused for `unlock_time` (Arch's defaults: 3, 15 min, 10 min). Its record of this user's
    // failures is readable without root, so say how many tries are left, or how long to wait.

    // When the account unlocks again (ms since the epoch), 0 if it isn't locked out
    property real lockedUntil: 0

    function describeFailures(text: string): void {
        const settings = { deny: 3, fail_interval: 900, unlock_time: 600 };
        const failures = [];
        for (const line of text.split("\n")) {
            const setting = line.match(/^conf\s+(deny|fail_interval|unlock_time)\s*=\s*(\d+)/);
            if (setting)
                settings[setting[1]] = parseInt(setting[2]);
            const failure = line.match(/^(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d)\s.*\sV\s*$/);
            if (failure)
                failures.push(new Date(`${failure[1]}T${failure[2]}`).getTime());
        }
        const now = Date.now();
        const recent = failures.filter(time => now - time < settings.fail_interval * 1000);
        if (recent.length >= settings.deny) {
            lockedUntil = Math.max(...recent) + settings.unlock_time * 1000;
            showLockout();
        } else if (recent.length > 0) {
            const left = settings.deny - recent.length;
            message = `Wrong password · ${left} ${left === 1 ? "try" : "tries"} left`;
        }
    }

    function showLockout(): void {
        const seconds = Math.ceil((lockedUntil - Date.now()) / 1000);
        if (seconds <= 0) {
            lockedUntil = 0;
            message = "";
            return;
        }
        const minutes = Math.ceil(seconds / 60);
        message = `Too many wrong passwords · try again in ${minutes} min`;
    }

    Timer {
        running: root.lockedUntil > 0
        interval: 5000
        repeat: true
        onTriggered: root.showLockout()
    }

    Process {
        id: faillock
        command: ["sh", "-c", "faillock --user \"$USER\"; sed -n 's/^[[:space:]]*\\(deny\\|fail_interval\\|unlock_time\\)/conf \\1/p' /etc/security/faillock.conf"]
        stdout: StdioCollector {
            onStreamFinished: root.describeFailures(text)
        }
    }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            color: Theme.background

            LockContent {
                anchors.fill: parent
                lock: root
            }
        }
    }

    LazyLoader {
        active: root.previewing

        FloatingWindow {
            title: "Lockscreen preview"
            implicitWidth: 1280
            implicitHeight: 720
            color: Theme.background
            onClosed: root.previewing = false

            LockContent {
                anchors.fill: parent
                lock: root
                preview: true
            }
        }
    }

    // Locked when the shell last stopped: lock again straight away
    FileView {
        id: flag
        path: Quickshell.statePath("locked")
        printErrors: false
        onLoaded: {
            if (text().trim() === "locked")
                root.lock();
        }
    }

    Timer {
        id: capsDelay
        interval: 150
        onTriggered: caps.running = true
    }

    Process {
        id: caps
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.capsLock = JSON.parse(text).keyboards.some(k => k.capsLock);
                } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim();
                if (name !== "")
                    root.userName = name;
            }
        }
    }
}

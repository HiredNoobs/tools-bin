import QtQuick

// SDDM theme that looks like Quickshell's lockscreen: it is the same LockLayout.qml (setup copies
// it in from dotfiles/.config/quickshell/lock), fed from SDDM instead of the shell.
// What the shell gets from its services comes from files here, as the greeter runs as the sddm
// user before anyone logs in (reading them needs QML_XHR_ALLOW_FILE_READ, set in sddm.conf.d):
// - battery from /sys, Wi-Fi signal from /proc/net/wireless, and its name from `runDir`
//   (written there by a NetworkManager dispatcher script, as only root can read it)
// - wallpaper, colours (pywal's colors.json) and avatars (faces/<user>) from `sharedDir`, which
//   the user owns and setup fills
// Clicking the name switches user, and the session button opens a list of sessions, when there's
// more than one of either. Nothing is playing and no notifications are waiting at login, so those
// stay hidden.
Item {
    id: root

    readonly property string sharedDir: config.sharedDir || "/var/lib/quickshell-lock"
    readonly property string runDir: config.runDir || "/run/quickshell-lock"

    // Text of a local file, "" if it can't be read
    function read(path: string): string {
        const request = new XMLHttpRequest();
        request.open("GET", `file://${path}`, false);
        try {
            request.send();
        } catch (e) {
            return "";
        }
        return request.status === 200 || request.status === 0 ? request.responseText : "";
    }

    // --- Users and sessions (SDDM gives models; these make them indexable)

    property int userIndex: Math.max(0, userModel.lastIndex)
    // The session last logged into, as SDDM remembers it (in its own state file); with none
    // remembered SDDM says the first, so `defaultSession` from theme.conf is used instead
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    readonly property bool sessionRemembered: /^Session=\S/m.test(read("/var/lib/sddm/state.conf"))

    Instantiator {
        id: users
        model: userModel
        delegate: QtObject {
            property string name: model.name
            property string realName: model.realName
            property string icon: model.icon
        }
    }

    Instantiator {
        id: sessions
        model: sessionModel
        delegate: QtObject {
            property string name: model.name
            property string file: model.file
        }
        onObjectAdded: (index, object) => {
            if (!root.sessionRemembered && config.defaultSession && object.file.endsWith(config.defaultSession))
                root.sessionIndex = index;
        }
    }

    readonly property var user: users.count > userIndex ? users.objectAt(userIndex) : null
    readonly property var sessionNames: {
        const names = [];
        for (let i = 0; i < sessions.count; i++)
            names.push(sessions.objectAt(i)?.name ?? "");
        return names;
    }

    // --- Colours, from the user's pywal colours if setup shared them

    property var wal: {
        try {
            return JSON.parse(read(`${sharedDir}/colors.json`));
        } catch (e) {
            return null;
        }
    }

    // --- Battery and network, read every 10 s

    property bool batteryPresent: false
    property int batteryCapacity: 0
    property bool batteryCharging: false
    property bool batteryPlugged: false
    property string networkIcon: "\u{EB01}"
    property string networkName: "Offline"

    function refreshStatus(): void {
        // Battery, as services/Battery.qml shows it
        batteryPresent = false;
        for (const name of ["BAT0", "BAT1", "BAT2", "BATT", "CMB0"]) {
            const capacity = read(`/sys/class/power_supply/${name}/capacity`).trim();
            if (capacity === "")
                continue;
            const status = read(`/sys/class/power_supply/${name}/status`).trim();
            batteryPresent = true;
            batteryCapacity = parseInt(capacity);
            batteryCharging = status === "Charging";
            batteryPlugged = status === "Not charging";
            break;
        }

        // Wi-Fi from the wireless table (quality out of 70), else a wired link that's up
        for (const line of read("/proc/net/wireless").split("\n").slice(2)) {
            const match = line.match(/^\s*(\S+):\s+\S+\s+(\d+)/);
            if (match && read(`/sys/class/net/${match[1]}/operstate`).trim() === "up") {
                const strength = Math.min(1, parseInt(match[2]) / 70);
                networkIcon = ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][Math.min(4, Math.floor(strength * 5))];
                networkName = read(`${runDir}/ssid`).trim() || "Wi-Fi";
                return;
            }
        }
        for (const line of read("/proc/net/dev").split("\n").slice(2)) {
            const name = line.split(":")[0].trim();
            if (/^(en|eth)/.test(name) && read(`/sys/class/net/${name}/operstate`).trim() === "up") {
                networkIcon = "\u{EF09}";
                networkName = "Wired";
                return;
            }
        }
        networkIcon = "\u{EB01}";
        networkName = "Offline";
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    // --- The screen

    LockLayout {
        id: layout
        anchors.fill: parent

        wallpaper: `file://${root.sharedDir}/wallpaper`
        background: root.wal?.special?.background ?? config.background ?? "#282828"
        text: root.wal?.colors?.color7 ?? config.text ?? "#d5c4a1"
        accent: root.wal?.colors?.color9 ?? config.accent ?? "#fb4934"
        fontFamily: config.font || "CodeNewRoman Nerd Font Propo"

        userName: root.user ? root.user.realName || root.user.name : ""
        avatars: root.user ? [`file://${root.sharedDir}/faces/${root.user.name}`, root.user.icon.startsWith("/") ? `file://${root.user.icon}` : root.user.icon] : []
        userSwitchable: users.count > 1
        onUserClicked: {
            root.userIndex = (root.userIndex + 1) % users.count;
            password = "";
            message = "";
        }
        sessions: root.sessionNames
        sessionIndex: root.sessionIndex
        onSessionPicked: index => root.sessionIndex = index

        capsLock: keyboard.capsLock
        onSubmitted: {
            if (busy || password === "" || !root.user)
                return;
            busy = true;
            message = "";
            sddm.login(root.user.name, password, root.sessionIndex);
        }

        batteryPresent: root.batteryPresent
        batteryCapacity: root.batteryCapacity
        batteryIcon: root.batteryCharging || root.batteryPlugged ? "\u{F0084}" : ["\u{F007B}", "\u{F007C}", "\u{F007E}", "\u{F0080}", "\u{F0082}", "\u{F0079}"][Math.min(5, Math.floor(root.batteryCapacity / 100 * 6))]
        batteryColour: root.batteryCharging ? "#26A65B" : root.batteryCapacity <= 20 ? critical : root.batteryCapacity <= 30 ? warning : accent
        networkIcon: root.networkIcon
        networkName: root.networkName

        powerActions: [
            ...(sddm.canSuspend ? [{ icon: "\u{23FE}", name: "Sleep", confirm: false }] : []),
            ...(sddm.canReboot ? [{ icon: "\u{EAD2}", name: "Reboot", confirm: true }] : []),
            ...(sddm.canPowerOff ? [{ icon: "\u{23FB}", name: "Shut down", confirm: true }] : [])
        ]
        onPowerAction: name => {
            if (name === "Sleep")
                sddm.suspend();
            else if (name === "Reboot")
                sddm.reboot();
            else if (name === "Shut down")
                sddm.powerOff();
        }
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            layout.busy = false;
            layout.password = "";
            layout.failures++;
            layout.message = "Wrong password";
        }
    }
}

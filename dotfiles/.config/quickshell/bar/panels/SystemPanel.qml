import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

// Opened from the Arch button (on the last tab used) or Super+Esc (Power tab), with tabs like
// the control centre:
// - System: battery, CPU, memory, temperature and disk usage (CPU and memory open htop sorted
//   by them, temperature opens btop, a disk opens yazi there), and pending updates.
// - Power: who and how long up, keep awake, power profile, and the power actions. Keyboard: Left/Right or
//   Tab/Shift+Tab select an action (the first press selects Lock or Shutdown), Enter runs it
//   (twice for the ones that confirm).
// Esc closes.
Column {
    id: root

    property string tab: "system"

    signal closeRequested
    signal tabRequested(string name)

    readonly property var tabs: [
        { name: "system", icon: "\u{F0EE0}", label: "System" },
        { name: "power", icon: "\u{23FB}", label: "Power" }
    ]

    function run(action: var): void {
        action();
        closeRequested();
    }

    width: 400
    spacing: 12

    // After the panel host has taken focus for itself, so the keys below reach the panel
    Component.onCompleted: Qt.callLater(forceActiveFocus)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            closeRequested();
            event.accepted = true;
            return;
        }
        // The Power tab's keys
        if (content.item?.handleKey?.(event))
            event.accepted = true;
    }

    TabBar {
        width: parent.width
        tabs: root.tabs
        current: root.tab
        onTabRequested: name => root.tabRequested(name)
    }

    Loader {
        id: content
        width: parent.width
        sourceComponent: ({
                "system": systemTab,
                "power": powerTab
            })[root.tab] ?? null
        onLoaded: fadeIn.restart()
    }

    NumberAnimation {
        id: fadeIn
        target: content
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }

    Component {
        id: systemTab

        Column {
            id: system

            // [{ mount, size, used }] in bytes, read each time the tab opens
            property var disks: []

            spacing: 10

            function gib(bytes: real): string {
                const g = bytes / 1073741824;
                return g >= 100 ? g.toFixed(0) + "G" : g.toFixed(1) + "G";
            }

            // Real filesystems only, without the EFI/boot partition
            Process {
                running: true
                command: ["df", "-B1", "--output=target,size,used", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
                stdout: StdioCollector {
                    // The mount point can have spaces (a drive's label), so the numbers are read from the end
                    onStreamFinished: system.disks = text.trim().split("\n").slice(1)
                        .map(line => line.trim().match(/^(.*\S)\s+(\d+)\s+(\d+)$/))
                        .filter(f => f && !f[1].startsWith("/boot") && !f[1].startsWith("/efi"))
                        .map(f => ({ mount: f[1], size: Number(f[2]), used: Number(f[3]) }))
                }
            }

            // Laptop only
            PanelSection {
                visible: Battery.present
                text: "Battery"
            }

            StatBar {
                visible: Battery.present
                width: parent.width
                icon: Battery.icon
                label: Battery.status
                value: `${Battery.capacity}%`
                fraction: Battery.capacity / 100
                barColour: Battery.colour
            }

            PanelSection {
                text: "Usage"
            }

            StatBar {
                width: parent.width
                icon: "\u{F0EE0}"
                label: "CPU"
                clickable: true
                onClicked: root.run(() => Exec.floating("kitty htop --sort-key PERCENT_CPU", true))
                value: `${SysStats.cpuUsage}%`
                fraction: SysStats.cpuUsage / 100
            }

            StatBar {
                width: parent.width
                icon: "\u{EFC5}"
                label: "Memory"
                clickable: true
                onClicked: root.run(() => Exec.floating("kitty htop --sort-key PERCENT_MEM", true))
                value: `${SysStats.memUsedGiB.toFixed(1)}G / ${SysStats.memTotalGiB.toFixed(1)}G`
                fraction: SysStats.memTotalGiB > 0 ? SysStats.memUsedGiB / SysStats.memTotalGiB : 0
            }

            StatBar {
                width: parent.width
                icon: "\u{F2C9}"
                label: "Temperature"
                clickable: true
                onClicked: root.run(() => Exec.floating("kitty btop", true))
                value: `${SysStats.temperature}°C`
                fraction: SysStats.temperature / 100
            }

            Repeater {
                model: system.disks

                StatBar {
                    required property var modelData

                    width: system.width
                    icon: "\u{F02CA}"
                    label: modelData.mount === "/" ? "Disk" : `Disk ${modelData.mount}`
                    value: `${system.gib(modelData.used)} / ${system.gib(modelData.size)}`
                    fraction: modelData.size > 0 ? modelData.used / modelData.size : 0
                    barColour: fraction > 0.9 ? Theme.critical : Theme.accent
                    clickable: true
                    onClicked: root.run(() => Exec.floating(`kitty yazi ${Exec.quote(modelData.mount)}`, true))
                }
            }

            // Pending updates: a count, the list on click, no pop-ups
            PanelSection {
                visible: Updates.available
                text: "Updates"
            }

            ListRow {
                id: updatesRow

                // Stays open for the session (see PanelState)
                readonly property bool expanded: PanelState.isOpen("updates", "list")

                visible: Updates.available
                width: parent.width
                clickable: Updates.packages.length > 0
                icon: "\u{F03D7}"
                label: {
                    const count = Updates.packages.length;
                    if (Updates.lastChecked === null)
                        return Updates.checking ? "Checking for updates…" : "Not checked yet";
                    return count === 0 ? "Up to date" : `${count} update${count === 1 ? "" : "s"} pending`;
                }
                sublabel: {
                    if (Updates.checking)
                        return "Checking…";
                    if (Updates.lastChecked === null)
                        return "";
                    const minutes = Math.round((Date.now() - Updates.lastChecked) / 60000);
                    const ago = minutes < 1 ? "just now" : minutes < 60 ? `${minutes} min ago` : `${Math.round(minutes / 60)} h ago`;
                    return Updates.failed ? `Check failed ${ago}` : `Checked ${ago}`;
                }
                onClicked: PanelState.toggle("updates", "list")

                Row {
                    spacing: 6

                    PanelButton {
                        icon: "\u{F0450}"
                        onClicked: Updates.check()
                    }

                    // Runs pacman in a terminal, then checks again
                    PanelButton {
                        visible: Updates.packages.length > 0
                        label: "Update"
                        onClicked: root.run(() => Exec.floating("kitty --hold sh -c 'sudo pacman -Syu; qs ipc call updates check'", true))
                    }
                }
            }

            ListView {
                visible: updatesRow.expanded && Updates.packages.length > 0
                width: parent.width
                height: Math.min(contentHeight, 200)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Updates.packages

                delegate: Item {
                    required property var modelData

                    width: ListView.view.width
                    height: 22

                    PanelText {
                        x: 10
                        width: parent.width * 0.45
                        elide: Text.ElideRight
                        text: modelData.name
                    }

                    PanelText {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        width: parent.width * 0.5
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        text: `${modelData.from} → ${modelData.to}`
                        dim: true
                        font.pixelSize: Theme.panelFontSize - 2
                    }
                }
            }
        }
    }

    Component {
        id: powerTab

        Column {
            id: power

            // Keyboard selection among the actions, -1 until a key selects one
            property int selected: -1
            property real uptimeSeconds: 0

            readonly property var actions: [
                { icon: "\u{F023}", name: "Lock", command: "loginctl lock-session", confirm: false },
                { icon: "\u{23FE}", name: "Sleep", command: "systemctl suspend-then-hibernate || systemctl suspend", confirm: false },
                { icon: "\u{F0343}", name: "Logout", command: "hyprshutdown -t 'Logging out...'", confirm: true },
                { icon: "\u{EAD2}", name: "Reboot", command: "hyprshutdown -t 'Rebooting...' --post-cmd 'systemctl reboot'", confirm: true },
                { icon: "\u{23FB}", name: "Shutdown", command: "hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff'", confirm: true }
            ]

            function move(delta: int): void {
                const count = actions.length;
                selected = selected < 0 ? (delta > 0 ? 0 : count - 1) : (selected + delta + count) % count;
            }

            // Called by the panel for each key; true if used
            function handleKey(event): bool {
                switch (event.key) {
                case Qt.Key_Right:
                case Qt.Key_Down:
                case Qt.Key_Tab:
                    move(1);
                    return true;
                case Qt.Key_Left:
                case Qt.Key_Up:
                case Qt.Key_Backtab:
                    move(-1);
                    return true;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    buttons.itemAt(selected)?.activate();
                    return true;
                }
                return false;
            }

            // "3 days, 2 hours" / "2 hours, 5 minutes" / "5 minutes"
            function formatUptime(seconds: real): string {
                const days = Math.floor(seconds / 86400);
                const hours = Math.floor(seconds % 86400 / 3600);
                const minutes = Math.floor(seconds % 3600 / 60);
                const part = (n, unit) => `${n} ${unit}${n === 1 ? "" : "s"}`;
                if (days > 0)
                    return `${part(days, "day")}, ${part(hours, "hour")}`;
                if (hours > 0)
                    return `${part(hours, "hour")}, ${part(minutes, "minute")}`;
                return part(minutes, "minute");
            }

            spacing: 12

            FileView {
                id: uptime
                path: "/proc/uptime"
                onLoaded: power.uptimeSeconds = Number(text().split(" ")[0])
            }

            FileView {
                id: hostname
                path: "/etc/hostname"
            }

            Timer {
                interval: 60000
                running: true
                repeat: true
                onTriggered: uptime.reload()
            }

            // Who and how long up
            Item {
                width: parent.width
                height: who.implicitHeight

                PanelText {
                    id: who
                    text: `${Quickshell.env("USER")}@${hostname.text().trim()}`
                    font.bold: true
                }

                PanelText {
                    anchors.right: parent.right
                    anchors.verticalCenter: who.verticalCenter
                    text: `up ${power.formatUptime(power.uptimeSeconds)}`
                    dim: true
                }
            }

            // Keep awake (a quick toggle instead when the control centre is on)
            ListRow {
                visible: !Theme.controlCentre
                width: parent.width
                icon: KeepAwake.enabled ? "\u{F0176}" : "\u{F0150}"
                label: "Keep awake"
                sublabel: KeepAwake.enabled ? "Won't lock, turn off the screen or sleep" : "Lock, screen off and sleep when idle"
                onClicked: KeepAwake.enabled = !KeepAwake.enabled

                Toggle {
                    checked: KeepAwake.enabled
                    onToggled: KeepAwake.enabled = !KeepAwake.enabled
                }
            }

            // Power profile, when power-profiles-daemon is running
            Row {
                visible: profilesCheck.present
                width: parent.width
                spacing: 8

                Process {
                    id: profilesCheck

                    property bool present: false

                    command: ["sh", "-c", "command -v powerprofilesctl"]
                    running: true
                    onExited: code => present = code === 0
                }

                Repeater {
                    model: [
                        { profile: PowerProfile.PowerSaver, icon: "\u{F032A}", name: "Saver" },
                        { profile: PowerProfile.Balanced, icon: "\u{F0A9F}", name: "Balanced" },
                        { profile: PowerProfile.Performance, icon: "\u{F04C5}", name: "Performance" }
                    ].filter(p => p.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

                    PanelButton {
                        required property var modelData

                        width: (power.width - 2 * 8) / 3
                        icon: modelData.icon
                        label: modelData.name
                        highlighted: PowerProfiles.profile === modelData.profile
                        onClicked: PowerProfiles.profile = modelData.profile
                    }
                }
            }

            Row {
                spacing: 8

                Repeater {
                    id: buttons
                    model: power.actions

                    // With `confirm`, the first press asks "Confirm?" for 3s and a second runs
                    // it, so a stray click or key can't end the session
                    Rectangle {
                        id: action

                        required property var modelData
                        required property int index
                        property bool armed: false
                        readonly property bool lit: mouse.containsMouse || index === power.selected || armed

                        function activate(): void {
                            if (modelData.confirm && !armed) {
                                armed = true;
                                disarm.restart();
                                return;
                            }
                            armed = false;
                            root.run(() => Exec.run(modelData.command));
                        }

                        width: (power.width - 4 * 8) / 5
                        height: 72
                        radius: 10
                        color: lit ? Theme.surfaceHover : Theme.surface

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            PanelText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: action.modelData.icon
                                font.pixelSize: 22
                                color: action.lit ? Theme.accent : Theme.text
                            }

                            PanelText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: action.armed ? "Confirm?" : action.modelData.name
                                font.pixelSize: Theme.panelFontSize - 1
                                color: action.lit ? Theme.accent : Theme.text
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: action.activate()
                        }

                        Timer {
                            id: disarm
                            interval: 3000
                            onTriggered: action.armed = false
                        }
                    }
                }
            }
        }
    }
}

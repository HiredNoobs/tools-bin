pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Removable drives (USB sticks, SD cards) via udisks: their state, open/mount/unmount/eject, and
// mounting them when they're plugged in (or found at start), with a notification, as udiskie
// did. Encrypted partitions (BitLocker, LUKS) unlock with a password or recovery key, then
// mount like the rest; swap and RAID/LVM partitions are left alone.
Singleton {
    id: root

    // [{ path, model, size, partitions: [{ path, label, size, fstype, mountpoint, encryption,
    // cryptPath, locked }] }]. An encrypted partition's path, fstype and mountpoint are those of
    // what's inside once unlocked; cryptPath is the partition itself, encryption "BitLocker" or
    // "crypto_LUKS" ("" when not encrypted).
    property var drives: []
    // Last action error per drive path
    property var errors: ({})
    // Partition to open once it has been mounted
    property string pendingOpen: ""
    // Drives seen already, so each is only mounted when it first appears
    property var known: []
    readonly property var unmountable: ["crypto_LUKS", "BitLocker", "swap", "LVM2_member", "linux_raid_member"]
    readonly property var encryptions: ["crypto_LUKS", "BitLocker"]
    // The encrypted partition being unlocked (its cryptPath, "" when none)
    readonly property string unlocking: unlocker.running ? unlocker.cryptPath : ""

    signal unlocked(string cryptPath)

    function refresh(): void {
        query.running = true;
    }

    function partitionByPath(path: string): var {
        for (const drive of drives) {
            const partition = drive.partitions.find(p => p.path === path);
            if (partition)
                return partition;
        }
        return null;
    }

    function mount(partition: var, drive: var): void {
        run(["udisksctl", "mount", "--no-user-interaction", "-b", partition.path], drive.path);
    }

    function unmount(partition: var, drive: var): void {
        run(["udisksctl", "unmount", "--no-user-interaction", "-b", partition.path], drive.path);
    }

    // Unmount what's in an unlocked partition, then lock it
    function lock(partition: var, drive: var): void {
        run(["sh", "-c", lockSteps(partition).join(" && ")], drive.path);
    }

    function lockSteps(partition: var): var {
        const steps = [];
        if (partition.mountpoint)
            steps.push(`udisksctl unmount --no-user-interaction -b ${Exec.quote(partition.path)}`);
        if (partition.encryption && !partition.locked)
            steps.push(`udisksctl lock --no-user-interaction -b ${Exec.quote(partition.cryptPath)}`);
        return steps;
    }

    // Unlocks an encrypted partition with a password or recovery key, then mounts it. The
    // password goes to udisks on stdin, never on a command line. Exits 1 if it stays locked, 2
    // if it unlocked but what's inside couldn't be mounted. False if it couldn't start (another
    // unlock is running, or it isn't locked).
    function unlock(partition: var, drive: var, passphrase: string): bool {
        if (unlocker.running || !partition.locked)
            return false;
        const cleared = Object.assign({}, errors);
        delete cleared[drive.path];
        errors = cleared;
        unlocker.drivePath = drive.path;
        unlocker.cryptPath = partition.cryptPath;
        unlocker.passphrase = passphrase;
        unlocker.command = ["sh", "-c", `
            udisksctl unlock --no-user-interaction -b "$1" --key-file /dev/stdin >/dev/null || exit 1
            dev=$(lsblk -nro PATH,TYPE "$1" | awk '$2 == "crypt" { print $1; exit }')
            [ -z "$dev" ] || udisksctl mount --no-user-interaction -b "$dev" >/dev/null || exit 2
        `, "sh", partition.cryptPath];
        unlocker.running = true;
        return true;
    }

    // Unmount (and lock) everything on the drive, then power it off so it's safe to pull out
    function eject(drive: var): void {
        const steps = [];
        for (const partition of drive.partitions)
            steps.push(...lockSteps(partition));
        steps.push(`udisksctl power-off --no-user-interaction -b ${Exec.quote(drive.path)}`);
        run(["sh", "-c", steps.join(" && ")], drive.path);
    }

    // Opens the partition in yazi, mounting it first if needed
    function open(partition: var, drive: var): void {
        if (partition.mountpoint) {
            Exec.floating(`kitty yazi ${Exec.quote(partition.mountpoint)}`, true);
            return;
        }
        pendingOpen = partition.path;
        mount(partition, drive);
    }

    function run(command: var, drivePath: string): void {
        if (action.running)
            return;
        const cleared = Object.assign({}, errors);
        delete cleared[drivePath];
        errors = cleared;
        action.drivePath = drivePath;
        action.command = command;
        action.running = true;
    }

    function parse(json: string): void {
        const removable = d => (d.rm || d.hotplug) && d.type === "disk" && ["usb", "mmc"].includes(d.tran ?? (d.name.startsWith("mmcblk") ? "mmc" : ""));
        const toPartition = p => {
            const encryption = encryptions.includes(p.fstype) ? p.fstype : "";
            // Unlocked, lsblk shows what's inside as its child
            const inner = encryption ? (p.children ?? []).find(c => c.type === "crypt") ?? null : null;
            const shown = inner ?? p;
            return {
                path: shown.path,
                label: inner?.label || p.label || p.name,
                size: p.size,
                fstype: inner ? (inner.fstype ?? "") : p.fstype,
                mountpoint: shown.mountpoint || "",
                encryption: encryption,
                cryptPath: encryption ? p.path : "",
                locked: encryption !== "" && !inner
            };
        };

        drives = JSON.parse(json).blockdevices.filter(removable).map(d => ({
            path: d.path,
            model: (d.model || "Removable drive").trim(),
            size: d.size,
            // Drives without a partition table carry the filesystem themselves
            partitions: (d.children ?? (d.fstype ? [d] : [])).filter(p => p.fstype).map(toPartition)
        }));

        // New drives: mount what can be, one after the other, telling how it went
        const fresh = drives.filter(d => !known.includes(d.path));
        known = drives.map(d => d.path);
        for (const drive of fresh) {
            const steps = drive.partitions
                .filter(p => !p.mountpoint && !unmountable.includes(p.fstype))
                .map(p => {
                    const device = Exec.quote(p.path);
                    const name = Exec.quote(p.label);
                    return `if udisksctl mount --no-user-interaction -b ${device} >/dev/null 2>"$err"; then notify-send -a Drives -i drive-removable-media "Mounted "${name} "$(findmnt -no TARGET ${device})"; else notify-send -a Drives -i drive-removable-media "Couldn't mount "${name} "$(tail -n 1 "$err" | sed 's/^Error.*: //')"; fi`;
                });
            if (steps.length > 0)
                Exec.run(`err=$(mktemp); ${steps.join("; ")}; rm -f "$err"`);
        }

        if (pendingOpen !== "") {
            const partition = partitionByPath(pendingOpen);
            if (partition?.mountpoint) {
                pendingOpen = "";
                Exec.floating(`kitty yazi ${Exec.quote(partition.mountpoint)}`, true);
            }
        }
    }

    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["lsblk", "-J", "-o", "NAME,PATH,LABEL,SIZE,MOUNTPOINT,HOTPLUG,RM,TRAN,TYPE,FSTYPE,MODEL"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parse(text);
                } catch (e) {
                    root.drives = [];
                }
            }
        }
    }

    // udisks reports every change (plug, mount, unmount, eject); re-read after a burst settles
    Process {
        command: ["udisksctl", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: refreshTimer.restart()
        }
    }

    Process {
        id: action

        property string drivePath

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message !== "") {
                    const updated = Object.assign({}, root.errors);
                    // udisksctl errors are long; the last line has the reason
                    updated[action.drivePath] = message.split("\n").pop().replace(/^Error.*?: /, "");
                    root.errors = updated;
                    root.pendingOpen = "";
                }
            }
        }
        onExited: refreshTimer.restart()
    }

    Process {
        id: unlocker

        property string drivePath
        property string cryptPath
        property string passphrase

        stdinEnabled: true
        // The password, then end of input, so udisks reads exactly what was typed
        onStarted: {
            write(passphrase);
            passphrase = "";
            stdinEnabled = false;
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message !== "") {
                    const updated = Object.assign({}, root.errors);
                    // "Error unlocking /dev/sda1: GDBus.Error:…: Failed to activate device: Incorrect passphrase."
                    updated[unlocker.drivePath] = message.split("\n").pop().split(": ").pop();
                    root.errors = updated;
                }
            }
        }
        onExited: code => {
            passphrase = "";
            stdinEnabled = true;
            if (code === 0 || code === 2)
                root.unlocked(cryptPath);
            refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }
}

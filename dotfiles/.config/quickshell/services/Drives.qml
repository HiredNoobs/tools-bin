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
    // Partitions seen already (by cryptPath or path), so each is only mounted when it first
    // appears: a drive's partitions can show up a moment after the drive itself
    property var known: []
    readonly property var unmountable: ["crypto_LUKS", "BitLocker", "swap", "LVM2_member", "linux_raid_member"]
    readonly property var encryptions: ["crypto_LUKS", "BitLocker"]
    // The encrypted partition being unlocked (its cryptPath, "" when none)
    readonly property string unlocking: unlocker.current?.cryptPath ?? ""

    signal unlocked(string cryptPath)

    function refresh(): void {
        query.running = true;
    }

    function setError(drivePath: string, message: string): void {
        const updated = Object.assign({}, errors);
        if (message !== "")
            updated[drivePath] = message;
        else
            delete updated[drivePath];
        errors = updated;
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
        if (unlocker.busy || !partition.locked)
            return false;
        setError(drive.path, "");
        const cryptPath = partition.cryptPath;
        unlocker.enqueue({
            cryptPath: cryptPath,
            command: ["sh", "-c", `
                udisksctl unlock --no-user-interaction -b "$1" --key-file /dev/stdin >/dev/null || exit 1
                dev=$(lsblk -nro PATH,TYPE "$1" | awk '$2 == "crypt" { print $1; exit }')
                [ -z "$dev" ] || udisksctl mount --no-user-interaction -b "$dev" >/dev/null || exit 2
            `, "sh", cryptPath],
            input: passphrase,
            done: (code, stdout, stderr) => {
                // "Error unlocking /dev/sda1: GDBus.Error:…: Failed to activate device: Incorrect passphrase."
                const message = stderr.trim();
                if (message !== "")
                    root.setError(drive.path, message.split("\n").pop().split(": ").pop());
                if (code === 0 || code === 2)
                    root.unlocked(cryptPath);
                refreshTimer.restart();
            }
        });
        // Not kept here (the job above has its own copy until it's written)
        passphrase = "";
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

    // After any action still running (one at a time, in order); a failure's reason is shown
    // under its drive
    function run(command: var, drivePath: string): void {
        actions.enqueue({
            command: command,
            started: () => root.setError(drivePath, ""),
            done: (code, stdout, stderr) => {
                const message = stderr.trim();
                if (message !== "") {
                    // udisksctl errors are long; the last line has the reason
                    root.setError(drivePath, message.split("\n").pop().replace(/^Error.*?: /, ""));
                    root.pendingOpen = "";
                }
                refreshTimer.restart();
            }
        });
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

        // New partitions: mount what can be, one after the other, telling how it went
        const key = p => p.cryptPath || p.path;
        const seen = known;
        known = [].concat(...drives.map(d => d.partitions.map(key)));
        for (const drive of drives) {
            const steps = drive.partitions
                .filter(p => !seen.includes(key(p)) && !p.mountpoint && !unmountable.includes(p.fstype))
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

    ProcessQueue {
        id: actions
    }

    // The password goes on stdin, then end of input, so udisks reads exactly what was typed
    ProcessQueue {
        id: unlocker
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Removable drives (USB sticks, SD cards) via udisks: their state, open/mount/unmount/eject, and
// mounting them when they're plugged in (or found at start), with a notification, as udiskie
// did. Encrypted, swap and RAID/LVM partitions are left alone.
Singleton {
    id: root

    // [{ path, model, size, partitions: [{ path, label, size, fstype, mountpoint }] }]
    property var drives: []
    // Last action error per drive path
    property var errors: ({})
    // Partition to open once it has been mounted
    property string pendingOpen: ""
    // Drives seen already, so each is only mounted when it first appears
    property var known: []
    readonly property var unmountable: ["crypto_LUKS", "BitLocker", "swap", "LVM2_member", "linux_raid_member"]

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

    // Unmount everything on the drive, then power it off so it's safe to pull out
    function eject(drive: var): void {
        const steps = drive.partitions
            .filter(p => p.mountpoint)
            .map(p => `udisksctl unmount --no-user-interaction -b '${p.path}'`);
        steps.push(`udisksctl power-off --no-user-interaction -b '${drive.path}'`);
        run(["sh", "-c", steps.join(" && ")], drive.path);
    }

    // Opens the partition in yazi, mounting it first if needed
    function open(partition: var, drive: var): void {
        if (partition.mountpoint) {
            Exec.floating(`kitty yazi '${partition.mountpoint}'`, true);
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
        const toPartition = p => ({
            path: p.path,
            label: p.label || p.name,
            size: p.size,
            fstype: p.fstype,
            mountpoint: p.mountpoint || ""
        });

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
                Exec.floating(`kitty yazi '${partition.mountpoint}'`, true);
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

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }
}

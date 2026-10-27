import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Opened from the drives icon: each removable drive with its partitions, unlocking encrypted ones
Column {
    id: root

    signal closeRequested

    // Close when the last drive is removed (off inside the control centre, which switches tab instead)
    property bool closeWhenEmpty: true

    readonly property int driveCount: Drives.drives.length
    onDriveCountChanged: {
        if (closeWhenEmpty && driveCount === 0)
            closeRequested();
    }

    width: 340
    spacing: 10

    PanelSection {
        text: "Drives"
    }

    // udisks reports every change, and the drive list is read again each time: rows are kept
    // by device path (an encrypted partition by its own, which stays the same once unlocked),
    // so a password being typed isn't lost
    Repeater {
        model: ScriptModel {
            values: Drives.drives.map(drive => drive.path)
        }

        Column {
            id: driveBlock

            required property string modelData
            readonly property var drive: Drives.drives.find(d => d.path === modelData) ?? { path: modelData, model: "", size: "", partitions: [] }
            readonly property string error: Drives.errors[modelData] ?? ""

            width: root.width
            spacing: 2

            // The drive: model, size, eject
            ListRow {
                width: parent.width
                clickable: false
                icon: "\u{F02CA}"
                label: driveBlock.drive.model
                sublabel: driveBlock.drive.size

                PanelButton {
                    icon: "\u{F052}"
                    label: "Eject"
                    onClicked: Drives.eject(driveBlock.drive)
                }
            }

            // Its partitions: open, mount/unmount; encrypted ones unlock first (a password field
            // opens under the row) and can be locked again
            Repeater {
                model: ScriptModel {
                    values: driveBlock.drive.partitions.map(partition => partition.cryptPath || partition.path)
                }

                Column {
                    id: partitionBlock

                    required property string modelData
                    readonly property var partition: driveBlock.drive.partitions.find(p => (p.cryptPath || p.path) === modelData) ?? { path: modelData, label: "", size: "", fstype: "", mountpoint: "", encryption: "", cryptPath: "", locked: false }
                    readonly property bool mounted: partition.mountpoint !== ""
                    readonly property bool locked: partition.locked
                    readonly property string encryptionName: partition.encryption === "crypto_LUKS" ? "LUKS" : partition.encryption
                    // Whether the password field is open, in PanelState so it stays open when
                    // the panel closes and opens again (until it's unlocked or unplugged)
                    readonly property bool askingPassword: PanelState.isOpen("unlock", partition.cryptPath)

                    function setAsking(open: bool): void {
                        if (open !== askingPassword)
                            PanelState.toggle("unlock", partition.cryptPath);
                        if (open)
                            Qt.callLater(passwordField.focusInput);
                    }

                    x: 16
                    width: driveBlock.width - 16
                    spacing: 4

                    function unlock(): void {
                        if (passwordField.text !== "" && Drives.unlock(partition, driveBlock.drive, passwordField.text))
                            passwordField.text = "";
                    }

                    // Unlocked: the field closes
                    Connections {
                        target: Drives
                        function onUnlocked(cryptPath: string): void {
                            if (cryptPath === partitionBlock.partition.cryptPath)
                                partitionBlock.setAsking(false);
                        }
                    }

                    ListRow {
                        width: parent.width
                        icon: partitionBlock.partition.encryption === "" ? "" : partitionBlock.locked ? "\u{F033E}" : "\u{F0FC6}"
                        label: partitionBlock.partition.label
                        sublabel: {
                            const parts = [partitionBlock.partition.size];
                            if (partitionBlock.partition.encryption !== "")
                                parts.push(partitionBlock.encryptionName);
                            if (partitionBlock.locked)
                                parts.push("Locked");
                            else
                                parts.push(partitionBlock.partition.fstype, partitionBlock.mounted ? partitionBlock.partition.mountpoint : "Not mounted");
                            return parts.filter(p => p).join(" · ");
                        }
                        selected: partitionBlock.mounted || partitionBlock.askingPassword
                        onClicked: {
                            if (partitionBlock.locked) {
                                partitionBlock.setAsking(!partitionBlock.askingPassword);
                                return;
                            }
                            Drives.open(partitionBlock.partition, driveBlock.drive);
                            root.closeRequested();
                        }

                        Row {
                            spacing: 6

                            PanelButton {
                                visible: partitionBlock.locked
                                icon: "\u{F0FC6}"
                                label: Drives.unlocking === partitionBlock.partition.cryptPath ? "Unlocking…" : "Unlock"
                                onClicked: {
                                    if (partitionBlock.askingPassword && passwordField.text !== "") {
                                        partitionBlock.unlock();
                                        return;
                                    }
                                    partitionBlock.setAsking(true);
                                }
                            }

                            PanelButton {
                                visible: !partitionBlock.locked
                                label: partitionBlock.mounted ? "Unmount" : "Mount"
                                onClicked: partitionBlock.mounted ? Drives.unmount(partitionBlock.partition, driveBlock.drive) : Drives.mount(partitionBlock.partition, driveBlock.drive)
                            }

                            PanelButton {
                                visible: partitionBlock.partition.encryption !== "" && !partitionBlock.locked
                                icon: "\u{F033E}"
                                label: "Lock"
                                onClicked: Drives.lock(partitionBlock.partition, driveBlock.drive)
                            }
                        }
                    }

                    // Password or BitLocker recovery key; Enter unlocks
                    TextField {
                        id: passwordField
                        visible: partitionBlock.locked && partitionBlock.askingPassword
                        width: parent.width
                        password: true
                        placeholder: partitionBlock.partition.encryption === "BitLocker" ? "Password or recovery key" : "Password"
                        onAccepted: partitionBlock.unlock()
                    }
                }
            }

            PanelText {
                visible: driveBlock.drive.partitions.length === 0
                x: 16
                text: "No readable partitions"
                dim: true
            }

            PanelText {
                visible: driveBlock.error !== ""
                x: 16
                width: driveBlock.width - 16
                text: driveBlock.error
                color: Theme.accent
                wrapMode: Text.Wrap
            }
        }
    }
}

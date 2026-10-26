import QtQuick
import qs
import qs.components
import qs.services

// Opened from the drives icon: each removable drive with its partitions, unlocking encrypted ones
Column {
    id: root

    signal closeRequested

    // Close when the last drive is removed (off inside the control centre, which switches tab instead)
    property bool closeWhenEmpty: true

    // The rows are made again whenever udisks reports a change (another partition mounting, a
    // wrong password), so what's typed in a password field, and which one has the cursor, are
    // kept here by cryptPath (for as long as the panel is open; not a property to bind to)
    property var typed: ({})
    property string typingIn: ""

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

    Repeater {
        model: Drives.drives

        Column {
            id: driveBlock

            required property var modelData
            readonly property string error: Drives.errors[modelData.path] ?? ""

            width: root.width
            spacing: 2

            // The drive: model, size, eject
            ListRow {
                width: parent.width
                clickable: false
                icon: "\u{F02CA}"
                label: driveBlock.modelData.model
                sublabel: driveBlock.modelData.size

                PanelButton {
                    icon: "\u{F052}"
                    label: "Eject"
                    onClicked: Drives.eject(driveBlock.modelData)
                }
            }

            // Its partitions: open, mount/unmount; encrypted ones unlock first (a password field
            // opens under the row) and can be locked again
            Repeater {
                model: driveBlock.modelData.partitions

                Column {
                    id: partitionBlock

                    required property var modelData
                    readonly property bool mounted: modelData.mountpoint !== ""
                    readonly property bool locked: modelData.locked
                    readonly property string encryptionName: modelData.encryption === "crypto_LUKS" ? "LUKS" : modelData.encryption
                    // Whether the password field is open, in PanelState so it stays open when
                    // the drive list is read again (udisks reports every change)
                    readonly property bool askingPassword: PanelState.isOpen("unlock", modelData.cryptPath)

                    function setAsking(open: bool): void {
                        if (open !== askingPassword)
                            PanelState.toggle("unlock", modelData.cryptPath);
                        if (open)
                            Qt.callLater(passwordField.focusInput);
                        else if (root.typingIn === modelData.cryptPath)
                            root.typingIn = "";
                    }

                    x: 16
                    width: driveBlock.width - 16
                    spacing: 4

                    function unlock(): void {
                        if (passwordField.text !== "" && Drives.unlock(modelData, driveBlock.modelData, passwordField.text))
                            passwordField.text = "";
                    }

                    // Unlocked: the field closes
                    Connections {
                        target: Drives
                        function onUnlocked(cryptPath: string): void {
                            if (cryptPath === partitionBlock.modelData.cryptPath)
                                partitionBlock.setAsking(false);
                        }
                    }

                    ListRow {
                        width: parent.width
                        icon: partitionBlock.modelData.encryption === "" ? "" : partitionBlock.locked ? "\u{F033E}" : "\u{F0FC6}"
                        label: partitionBlock.modelData.label
                        sublabel: {
                            const parts = [partitionBlock.modelData.size];
                            if (partitionBlock.modelData.encryption !== "")
                                parts.push(partitionBlock.encryptionName);
                            if (partitionBlock.locked)
                                parts.push("Locked");
                            else
                                parts.push(partitionBlock.modelData.fstype, partitionBlock.mounted ? partitionBlock.modelData.mountpoint : "Not mounted");
                            return parts.filter(p => p).join(" · ");
                        }
                        selected: partitionBlock.mounted || partitionBlock.askingPassword
                        onClicked: {
                            if (partitionBlock.locked) {
                                partitionBlock.setAsking(!partitionBlock.askingPassword);
                                return;
                            }
                            Drives.open(partitionBlock.modelData, driveBlock.modelData);
                            root.closeRequested();
                        }

                        Row {
                            spacing: 6

                            PanelButton {
                                visible: partitionBlock.locked
                                icon: "\u{F0FC6}"
                                label: Drives.unlocking === partitionBlock.modelData.cryptPath ? "Unlocking…" : "Unlock"
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
                                onClicked: partitionBlock.mounted ? Drives.unmount(partitionBlock.modelData, driveBlock.modelData) : Drives.mount(partitionBlock.modelData, driveBlock.modelData)
                            }

                            PanelButton {
                                visible: partitionBlock.modelData.encryption !== "" && !partitionBlock.locked
                                icon: "\u{F033E}"
                                label: "Lock"
                                onClicked: Drives.lock(partitionBlock.modelData, driveBlock.modelData)
                            }
                        }
                    }

                    // Password or BitLocker recovery key; Enter unlocks
                    TextField {
                        id: passwordField
                        visible: partitionBlock.locked && partitionBlock.askingPassword
                        width: parent.width
                        password: true
                        placeholder: partitionBlock.modelData.encryption === "BitLocker" ? "Password or recovery key" : "Password"
                        onAccepted: partitionBlock.unlock()
                        onTextChanged: root.typed[partitionBlock.modelData.cryptPath] = passwordField.text
                        onInputFocusChanged: {
                            if (passwordField.inputFocus)
                                root.typingIn = partitionBlock.modelData.cryptPath;
                        }

                        Component.onCompleted: {
                            const cryptPath = partitionBlock.modelData.cryptPath;
                            passwordField.text = root.typed[cryptPath] ?? "";
                            if (passwordField.visible && root.typingIn === cryptPath)
                                Qt.callLater(passwordField.focusInput);
                        }
                    }
                }
            }

            PanelText {
                visible: driveBlock.modelData.partitions.length === 0
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

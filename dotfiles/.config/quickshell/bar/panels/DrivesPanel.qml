import QtQuick
import qs
import qs.components
import qs.services

// Opened from the drives icon: each removable drive with its partitions
Column {
    id: root

    signal closeRequested

    // Last drive removed while the panel was open
    readonly property int driveCount: Drives.drives.length
    onDriveCountChanged: {
        if (driveCount === 0)
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

            // Its partitions: open, mount/unmount
            Repeater {
                model: driveBlock.modelData.partitions

                ListRow {
                    id: partitionRow

                    required property var modelData
                    readonly property bool mounted: modelData.mountpoint !== ""

                    x: 16
                    width: driveBlock.width - 16
                    label: modelData.label
                    sublabel: [modelData.size, modelData.fstype, mounted ? modelData.mountpoint : "Not mounted"].join(" · ")
                    selected: mounted
                    onClicked: {
                        Drives.open(modelData, driveBlock.modelData);
                        root.closeRequested();
                    }

                    PanelButton {
                        label: partitionRow.mounted ? "Unmount" : "Mount"
                        onClicked: partitionRow.mounted ? Drives.unmount(partitionRow.modelData, driveBlock.modelData) : Drives.mount(partitionRow.modelData, driveBlock.modelData)
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

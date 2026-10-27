import QtQuick

// A block of rows inside a SettingsGroup, padded like a SettingRow: a device, a connection, a
// sound card…, usually starting with a BlockHeader
Item {
    id: root

    property int spacing: 10
    default property alias content: column.data

    width: parent?.width ?? 0
    implicitHeight: column.implicitHeight + 28

    Column {
        id: column
        x: 16
        y: 14
        width: parent.width - 32
        spacing: root.spacing
    }
}

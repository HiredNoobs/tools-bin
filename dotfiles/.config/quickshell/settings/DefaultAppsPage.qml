import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Settings › Default apps, in place of selectdefaultapplication: the app that opens links,
// folders, text, pictures, video, music, PDFs and email links (see DefaultApps).
Column {
    id: root

    spacing: 24

    Component.onCompleted: DefaultApps.refresh()

    SettingsGroup {
        title: "Open with"

        Repeater {
            model: DefaultApps.categories

            AppPicker {
                required property var modelData

                category: modelData
            }
        }
    }

    // A category's row, with its apps sliding open under it
    component AppPicker: Column {
        id: picker

        property var category
        property bool open: false
        readonly property string current: DefaultApps.defaults[category.key] ?? ""
        readonly property var apps: DefaultApps.apps(category.key)

        width: parent?.width ?? 0

        SettingRow {
            label: picker.category.title
            description: picker.category.description ?? ""
            changed: DefaultApps.changed(picker.category.key)
            onReset: DefaultApps.revert(picker.category.key)

            PanelButton {
                width: 240
                label: DefaultApps.appName(picker.current) || (picker.apps.length > 0 ? "Not set" : "No apps installed")
                icon: picker.open ? "\u{F077}" : "\u{F078}"
                highlighted: picker.open
                onClicked: {
                    picker.open = !picker.open;
                    if (picker.open)
                        list.setExpanded(true);
                }
            }
        }

        Column {
            visible: picker.open
            x: 16
            width: parent.width - 32
            bottomPadding: 12

            DropdownList {
                id: list
                width: parent.width
                maxHeight: 240
                items: picker.apps.map(app => ({
                            label: app.name,
                            sublabel: app.id,
                            iconSource: Quickshell.iconPath(app.icon, "application-x-executable"),
                            selected: app.id === picker.current,
                            value: app.id
                        }))
                onChosen: item => {
                    DefaultApps.setDefault(picker.category.key, item.value);
                    picker.open = false;
                }
            }

            PanelText {
                visible: picker.apps.length === 0
                leftPadding: 10
                text: "No installed app opens these."
                dim: true
            }
        }
    }
}

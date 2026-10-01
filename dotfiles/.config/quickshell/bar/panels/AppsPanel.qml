import QtQuick
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services

// Opened from the apps icon: one row per tray app. Clicking a row opens the app and
// focuses its window; the arrow expands the app's own menu in place.
Column {
    id: root

    signal closeRequested

    readonly property var items: SystemTray.items.values

    // Close when the last app quits (off inside the control centre, which switches tab instead)
    property bool closeWhenEmpty: true

    onItemsChanged: {
        if (closeWhenEmpty && items.length === 0)
            closeRequested();
    }

    width: 300
    spacing: 6

    PanelSection {
        text: "Apps"
    }

    Repeater {
        model: SystemTray.items

        Column {
            id: app

            required property SystemTrayItem modelData
            readonly property bool needsAttention: modelData.status === Status.NeedsAttention
            property bool expanded: false

            width: root.width
            spacing: 2

            ListRow {
                width: parent.width
                iconSource: app.modelData.icon
                label: app.modelData.tooltipTitle || app.modelData.title || app.modelData.id
                sublabel: app.needsAttention ? "Needs attention" : ""
                selected: app.expanded || app.needsAttention
                onClicked: {
                    // Some apps only offer a menu
                    if (app.modelData.onlyMenu) {
                        app.expanded = !app.expanded;
                    } else {
                        TrayApps.open(app.modelData);
                        root.closeRequested();
                    }
                }

                PanelButton {
                    visible: app.modelData.hasMenu
                    icon: app.expanded ? "\u{F078}" : "\u{F054}"
                    highlighted: app.expanded
                    onClicked: app.expanded = !app.expanded
                }
            }

            // Hidden when collapsed: an unloaded Loader keeps its old height
            Loader {
                active: app.expanded
                visible: app.expanded
                width: parent.width

                sourceComponent: TrayMenuLevel {
                    menu: app.modelData.menu
                    indent: 16
                    afterTrigger: () => root.closeRequested()
                }
            }
        }
    }
}

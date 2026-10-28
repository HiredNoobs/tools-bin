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

    // Also when opened with none (IPC)
    function closeIfEmpty(): void {
        if (closeWhenEmpty && items.length === 0)
            closeRequested();
    }
    onItemsChanged: closeIfEmpty()
    Component.onCompleted: closeIfEmpty()

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
            // The app's menu stays open for the session (see PanelState)
            readonly property bool expanded: PanelState.isOpen("trayApps", modelData.id)

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
                        PanelState.toggle("trayApps", app.modelData.id);
                    } else {
                        TrayApps.open(app.modelData);
                        root.closeRequested();
                    }
                }

                PickerButton {
                    visible: app.modelData.hasMenu
                    open: app.expanded
                    onClicked: PanelState.toggle("trayApps", app.modelData.id)
                }
            }

            // Hidden when collapsed: an unloaded Loader keeps its old height
            Loader {
                active: app.expanded
                visible: app.expanded
                width: parent.width

                sourceComponent: TrayMenuLevel {
                    menu: app.modelData.menu
                    stateKey: app.modelData.id
                    indent: 16
                    afterTrigger: () => root.closeRequested()
                }
            }
        }
    }
}

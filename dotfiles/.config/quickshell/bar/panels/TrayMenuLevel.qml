import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// One level of a tray app's menu. Submenus expand in place by loading this file again.
Column {
    id: root

    property var menu
    // Where this level is, as "<app id>/<entry>/…", to remember open submenus (PanelState)
    property string stateKey: ""
    property int indent: 0
    // Called after an entry is triggered, to close the panel
    property var afterTrigger: () => {}

    // Some apps mark keyboard shortcuts with "_" ("_Quit"), others send names like "ASUS_5G"
    // unescaped, so only drop an underscore at the start of a word
    function cleanLabel(text: string): string {
        return text.replace(/(^|\s)_(?=\S)/g, "$1");
    }

    function stateIcon(entry: QsMenuEntry): string {
        const checked = entry.checkState === Qt.Checked;
        if (entry.buttonType === QsMenuButtonType.CheckBox)
            return checked ? "\u{F14A}" : "\u{F096}";
        if (entry.buttonType === QsMenuButtonType.RadioButton)
            return checked ? "\u{F192}" : "\u{F10C}";
        return "";
    }

    spacing: 2

    QsMenuOpener {
        id: opener
        menu: root.menu
    }

    Repeater {
        model: opener.children

        Column {
            id: entry

            required property QsMenuEntry modelData
            readonly property string stateKey: `${root.stateKey}/${root.cleanLabel(modelData.text)}`
            readonly property bool expanded: modelData.hasChildren && PanelState.isOpen("trayMenus", stateKey)

            width: root.width

            function loadSubmenu(): void {
                if (expanded) {
                    submenu.setSource(Qt.resolvedUrl("TrayMenuLevel.qml"), {
                        menu: modelData,
                        stateKey: stateKey,
                        indent: root.indent + 16,
                        afterTrigger: root.afterTrigger
                    });
                } else {
                    submenu.source = "";
                }
            }

            onExpandedChanged: loadSubmenu()
            // Open already when created (remembered from earlier)
            Component.onCompleted: loadSubmenu()

            Rectangle {
                visible: entry.modelData.isSeparator
                width: parent.width
                height: 9
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Theme.surface
                }
            }

            ListRow {
                visible: !entry.modelData.isSeparator
                width: parent.width - root.indent
                x: root.indent
                icon: root.stateIcon(entry.modelData)
                label: root.cleanLabel(entry.modelData.text)
                selected: entry.expanded
                clickable: entry.modelData.enabled
                opacity: entry.modelData.enabled ? 1 : 0.4
                onClicked: {
                    if (entry.modelData.hasChildren) {
                        PanelState.toggle("trayMenus", entry.stateKey);
                    } else {
                        entry.modelData.triggered();
                        root.afterTrigger();
                    }
                }

                ExpandChevron {
                    visible: entry.modelData.hasChildren
                    expanded: entry.expanded
                }
            }

            // Hidden when collapsed: an unloaded Loader keeps its old height
            Loader {
                id: submenu
                visible: entry.expanded
                width: parent.width
            }
        }
    }
}

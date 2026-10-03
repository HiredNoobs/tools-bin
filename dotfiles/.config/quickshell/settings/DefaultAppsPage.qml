import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Settings › Default apps, in place of selectdefaultapplication: the app that opens links,
// folders, text, pictures, video, music, PDFs and email links, and single file types set apart
// from those (see DefaultApps).
Column {
    id: root

    spacing: 24

    Component.onCompleted: DefaultApps.refresh()

    SettingsGroup {
        title: "Open with"

        Repeater {
            model: DefaultApps.categories

            AppChooser {
                required property var modelData
                readonly property int separate: DefaultApps.overridesIn(modelData.key)

                label: modelData.title
                description: [modelData.description ?? "", separate > 0 ? `${separate} file type${separate > 1 ? "s" : ""} set separately below.` : ""].filter(s => s !== "").join(" ")
                current: DefaultApps.defaults[modelData.key] ?? ""
                apps: DefaultApps.apps(modelData.key)
                changed: DefaultApps.changed(modelData.key)
                onReset: DefaultApps.revert(modelData.key)
                onPicked: id => DefaultApps.setDefault(modelData.key, id)
            }
        }
    }

    SettingsGroup {
        title: "File types"

        // Set apart already
        Repeater {
            model: DefaultApps.overrides

            TypeChooser {
                required property string modelData

                type: modelData
                changed: true
                onReset: DefaultApps.removeOverride(modelData)
            }
        }

        Item {
            width: parent.width
            height: typeSearch.height + 24

            TextField {
                id: typeSearch
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                width: parent.width - 32
                placeholder: "Set one file type apart: search md, svg, discord…"
            }
        }

        Repeater {
            model: DefaultApps.findTypes(typeSearch.text, 20).filter(t => !DefaultApps.overrides.includes(t.type))

            TypeChooser {
                required property var modelData

                type: modelData.type
            }
        }

        PanelText {
            visible: typeSearch.text.trim() !== "" && DefaultApps.findTypes(typeSearch.text, 1).length === 0
            leftPadding: 16
            bottomPadding: 12
            text: "No file type matches."
            dim: true
        }
    }

    // A file type's row: its name, MIME type and extensions, and the app it opens with
    component TypeChooser: AppChooser {
        property string type
        readonly property var info: DefaultApps.typeInfo(type)
        readonly property var opener: DefaultApps.typeDefault(type)

        label: info.name
        description: [type, info.globs.slice(0, 5).map(glob => glob.replace(/^\*\./, ".")).join(" "), opener.automatic && opener.id !== "" ? "picked automatically" : ""].filter(s => s !== "").join(" · ")
        current: opener.id
        apps: DefaultApps.typeApps(type)
        allowOther: true
        onPicked: id => DefaultApps.setType(type, id)
    }

    // A row with its apps sliding open under it. With `allowOther`, "Other apps…" lists every
    // installed app, for one that can open the type without saying so.
    component AppChooser: Column {
        id: chooser

        property string label
        property string description
        property string current
        property var apps: []
        property bool allowOther: false
        property bool changed: false
        property bool open: false
        property bool showAll: false
        signal picked(string id)
        signal reset

        readonly property var shown: {
            if (!showAll)
                return apps;
            const query = otherSearch.text.trim().toLowerCase();
            return DefaultApps.allApps().filter(app => query === "" || app.name.toLowerCase().includes(query));
        }

        width: parent?.width ?? 0

        SettingRow {
            label: chooser.label
            description: chooser.description
            changed: chooser.changed
            onReset: chooser.reset()

            PanelButton {
                width: 240
                label: DefaultApps.appName(chooser.current) || (chooser.apps.length > 0 || chooser.allowOther ? "Not set" : "No apps installed")
                icon: chooser.open ? "\u{F077}" : "\u{F078}"
                highlighted: chooser.open
                onClicked: {
                    chooser.open = !chooser.open;
                    chooser.showAll = false;
                    if (chooser.open)
                        list.setExpanded(true);
                }
            }
        }

        Column {
            visible: chooser.open
            x: 16
            width: parent.width - 32
            spacing: 6
            bottomPadding: 12

            TextField {
                id: otherSearch
                visible: chooser.showAll
                width: parent.width
                placeholder: "Search apps…"
            }

            DropdownList {
                id: list
                width: parent.width
                maxHeight: 240
                items: [
                    ...chooser.shown.map(app => ({
                                label: app.name,
                                sublabel: app.id,
                                iconSource: Quickshell.iconPath(app.icon, "application-x-executable"),
                                selected: app.id === chooser.current,
                                value: app.id
                            })),
                    ...(chooser.allowOther && !chooser.showAll ? [{ label: "Other apps…", sublabel: "Any installed app", value: "" }] : [])
                ]
                onChosen: item => {
                    if (item.value === "") {
                        chooser.showAll = true;
                        otherSearch.text = "";
                        Qt.callLater(() => {
                            list.setExpanded(true);
                            otherSearch.focusInput();
                        });
                        return;
                    }
                    chooser.picked(item.value);
                    chooser.open = false;
                }
            }

            PanelText {
                visible: chooser.shown.length === 0 && !chooser.allowOther
                leftPadding: 10
                text: "No installed app opens these."
                dim: true
            }
        }
    }
}

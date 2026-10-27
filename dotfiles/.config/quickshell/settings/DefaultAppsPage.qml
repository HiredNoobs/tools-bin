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

    // A desktop's own list is read first, so what it sets wins over the choices here
    Banner {
        text: DefaultApps.overridingList !== "" ? `${DefaultApps.overridingList.replace(DefaultApps.home, "~")} is read before these choices, so what it sets wins. Move its lines into ~/.config/mimeapps.list, or delete it.` : ""
    }

    SettingsGroup {
        title: "Open with"

        Repeater {
            model: DefaultApps.categories

            AppChooser {
                required property var modelData
                readonly property int separate: DefaultApps.overridesIn(modelData.key)

                stateKey: `picker:apps:${modelData.key}`
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

        stateKey: `picker:type:${type}`
        label: info.name
        description: [type, info.globs.slice(0, 5).map(glob => glob.replace(/^\*\./, ".")).join(" "), opener.automatic && opener.id !== "" ? "picked automatically" : ""].filter(s => s !== "").join(" · ")
        current: opener.id
        apps: DefaultApps.typeApps(type)
        allowOther: true
        onPicked: id => DefaultApps.setType(type, id)
    }

    // A row with its apps sliding open under it. With `allowOther`, "Other apps…" lists every
    // installed app, for one that can open the type without saying so.
    component AppChooser: DropdownRow {
        id: chooser

        property string current
        property var apps: []
        property bool allowOther: false
        property bool showAll: false
        signal picked(string id)

        readonly property var shown: showAll ? DefaultApps.allApps().filter(app => query === "" || app.name.toLowerCase().includes(query)) : apps

        buttonLabel: DefaultApps.appName(current) || (apps.length > 0 || allowOther ? "Not set" : "No apps installed")
        searchable: showAll
        searchPlaceholder: "Search apps…"
        // "Other apps…" keeps it open, to list them all
        closeOnChoose: false
        onOpenChanged: {
            if (!open)
                showAll = false;
        }
        items: [
            ...shown.map(app => ({
                        label: app.name,
                        sublabel: app.id,
                        iconSource: Quickshell.iconPath(app.icon, "application-x-executable"),
                        selected: app.id === chooser.current,
                        value: app.id
                    })),
            ...(allowOther && !showAll ? [{ label: "Other apps…", sublabel: "Any installed app", value: "" }] : [])
        ]
        onChosen: item => {
            if (item.value === "") {
                chooser.showAll = true;
                chooser.focusSearch();
                return;
            }
            chooser.picked(item.value);
            chooser.setOpen(false);
        }

        PanelText {
            visible: chooser.shown.length === 0 && !chooser.allowOther
            leftPadding: 10
            text: "No installed app opens these."
            dim: true
        }
    }
}

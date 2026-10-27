import QtQuick
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Settings › Appearance, in place of nwg-look, qt6ct and Kvantum Manager: dark or light, the
// GTK and Qt (Kvantum) styles, icons, cursor, fonts (Qt can have its own), Qt's file chooser
// and the wallpaper. Applied to every toolkit at once (see Appearance). Also presets that set
// several at once (see Presets), the colour scheme (see ColourScheme) and the picture on the
// lock and login screens (see LockShare).
Column {
    id: root

    spacing: 24

    Component.onCompleted: Appearance.refresh()

    // Themes installed while it's open show up
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: Appearance.rescan()
    }

    // Toolkits set apart by other tools (nwg-look, qt6ct)
    Rectangle {
        visible: Appearance.mismatched
        width: parent.width
        height: mismatchRow.implicitHeight + 24
        radius: Theme.radius
        color: Qt.alpha(Theme.warning, 0.15)

        Row {
            id: mismatchRow
            anchors.verticalCenter: parent.verticalCenter
            x: 16
            width: parent.width - 32
            spacing: 12

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - fixButton.width - parent.spacing
                text: `Some apps don't use the choices below (another tool or an older change set them):\n${Appearance.mismatches.map(m => `• ${m}`).join("\n")}\n"Use everywhere" gives them the choices below too.`
                wrapMode: Text.WordWrap
                color: Theme.warning
            }

            PanelButton {
                id: fixButton
                anchors.verticalCenter: parent.verticalCenter
                label: "Use everywhere"
                highlighted: true
                onClicked: Appearance.applyAll()
            }
        }
    }

    SettingsGroup {
        title: "Presets"

        Flow {
            x: 16
            width: parent.width - 32
            spacing: 10
            topPadding: 16
            bottomPadding: 16

            Repeater {
                model: Presets.presets

                Rectangle {
                    id: presetTile

                    required property var modelData
                    readonly property bool current: Presets.isCurrent(modelData)
                    // The wallpaper's scheme shows the one in use only while it's in use
                    readonly property var scheme: modelData.colours === "wallpaper" ? (ShellSettings.colourSource === "wallpaper" ? ColourScheme.current : null) : ColourScheme.palettes[modelData.colours]

                    width: 150
                    height: 84
                    radius: Theme.radius
                    color: presetMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.width: current ? 2 : 0
                    border.color: Theme.accent

                    // Background with the text and accent on it, and four of the terminal's colours
                    Rectangle {
                        x: 10
                        y: 10
                        width: parent.width - 20
                        height: 38
                        radius: 6
                        color: presetTile.scheme?.background ?? Theme.surface
                        border.width: 1
                        border.color: Theme.surface

                        PanelText {
                            visible: !presetTile.scheme
                            anchors.centerIn: parent
                            text: "\u{F0E09}"
                            dim: true
                        }

                        Row {
                            visible: !!presetTile.scheme
                            anchors.centerIn: parent
                            spacing: 5

                            Repeater {
                                model: presetTile.scheme ? [presetTile.scheme.foreground, presetTile.scheme.accent, ...[2, 3, 4, 5].map(i => presetTile.scheme.colors[i])] : []

                                Rectangle {
                                    required property string modelData
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: modelData
                                }
                            }
                        }
                    }

                    PanelText {
                        x: 10
                        y: 56
                        width: parent.width - 20
                        elide: Text.ElideRight
                        text: (presetTile.current ? "\u{F012C} " : "") + presetTile.modelData.label
                        color: presetTile.current ? Theme.accent : Theme.text
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Presets.apply(presetTile.modelData)
                    }
                }
            }
        }

        SettingRow {
            label: "Change the cursor too"
            description: "Presets pick a cursor that suits them. Off, the cursor stays as it is."
            changed: !ShellSettings.isDefault("presetCursors")
            onReset: ShellSettings.reset("presetCursors")

            Toggle {
                checked: ShellSettings.presetCursors
                onToggled: ShellSettings.presetCursors = !checked
            }
        }
    }

    SettingsGroup {
        title: "Style"

        SettingRow {
            label: "Mode"
            changed: Appearance.changed("dark")
            onReset: Appearance.revert("dark")
            description: "Also switches the themes below to their dark or light version, where they have one."

            ChoiceButtons {
                choices: [true, false]
                current: Appearance.dark
                format: dark => dark ? "Dark" : "Light"
                onChosen: dark => Appearance.setDark(dark)
            }
        }

        ListPicker {
            label: "GTK apps"
            changed: Appearance.changed("gtkTheme")
            onReset: Appearance.revert("gtkTheme")
            description: "Theme for GTK apps (Firefox, file choosers, most of the desktop)."
            choices: Appearance.gtkThemes
            current: Appearance.gtkTheme
            onPicked: value => Appearance.setGtkTheme(value)
        }

        ListPicker {
            label: "Qt apps"
            changed: Appearance.changed("kvantumTheme")
            onReset: Appearance.revert("kvantumTheme")
            description: "Kvantum theme for Qt apps. They pick it up when next opened."
            choices: Appearance.kvantumThemes
            current: Appearance.kvantumTheme
            placeholder: "Kvantum's default"
            onPicked: value => Appearance.setKvantumTheme(value)
        }
    }

    SettingsGroup {
        title: "Icons and cursor"

        GalleryPicker {
            label: "Icons"
            changed: Appearance.changed("iconTheme")
            onReset: Appearance.revert("iconTheme")
            choices: Appearance.iconThemes
            current: Appearance.iconTheme
            pictures: name => Appearance.iconPreviews[name] ?? []
            onPicked: value => Appearance.setIconTheme(value)
        }

        // Each on a dark and a light background, as a cursor has to show up on both
        GalleryPicker {
            label: "Cursor"
            description: "The arrow, text beam and hand, on dark and light."
            changed: Appearance.changed("cursor")
            onReset: Appearance.revert("cursor")
            choices: Appearance.cursorThemes
            current: Appearance.cursorTheme
            cursors: true
            format: name => name.replace("-cursors", "")
            pictures: name => {
                const previews = Appearance.cursorPreviews[name] ?? {};
                return ["pointer", "text", "hand"].filter(role => previews[role]).map(role => previews[role]);
            }
            onPicked: value => Appearance.setCursor(value, Appearance.cursorSize)
        }

        SettingRow {
            label: "Cursor size"
            changed: Appearance.changed("cursorSize")
            onReset: Appearance.revert("cursorSize")

            ChoiceButtons {
                choices: [24, 32, 40, 48]
                current: Appearance.cursorSize
                onChosen: size => Appearance.setCursor(Appearance.cursorTheme, size)
            }
        }
    }

    SettingsGroup {
        title: "Fonts"

        ListPicker {
            label: "Interface"
            changed: Appearance.changed("font")
            onReset: Appearance.revert("font")
            choices: Appearance.fonts
            current: Appearance.font
            onPicked: value => Appearance.setFont(value, Appearance.fontSize)
        }

        SettingRow {
            sub: true
            label: "Size"
            changed: Appearance.changed("fontSize")
            onReset: Appearance.revert("fontSize")

            ChoiceButtons {
                choices: [9, 10, 11, 12, 13, 14]
                current: Appearance.fontSize
                onChosen: size => Appearance.setFont(Appearance.font, size)
            }
        }

        ListPicker {
            label: "Monospace"
            changed: Appearance.changed("monoFont")
            onReset: Appearance.revert("monoFont")
            description: "For terminals and code."
            choices: Appearance.monoFonts
            current: Appearance.monoFont
            onPicked: value => Appearance.setMonoFont(value, Appearance.monoSize)
        }

        SettingRow {
            sub: true
            label: "Size"
            changed: Appearance.changed("monoSize")
            onReset: Appearance.revert("monoSize")

            ChoiceButtons {
                choices: [9, 10, 11, 12, 13, 14]
                current: Appearance.monoSize
                onChosen: size => Appearance.setMonoFont(Appearance.monoFont, size)
            }
        }

        // Qt sizes fonts differently, so it can have its own: the rows below show while it does
        SettingRow {
            label: "Qt apps use the interface font"
            changed: Appearance.changed("qtFont")
            onReset: Appearance.revert("qtFont")
            description: Appearance.qtFont === "" ? "Off gives them their own, as Qt sizes fonts a little differently." : `Their own for now: ${Appearance.qtFont} ${Appearance.qtFontSize}.`

            Toggle {
                checked: Appearance.qtFont === ""
                onToggled: Appearance.setQtFont(checked ? Appearance.font : "", Appearance.fontSize)
            }
        }

        ListPicker {
            visible: Appearance.qtFont !== ""
            sub: true
            label: "Qt font"
            changed: Appearance.changed("qtFont")
            onReset: Appearance.revert("qtFont")
            choices: Appearance.fonts
            current: Appearance.qtFont
            onPicked: value => Appearance.setQtFont(value, Appearance.qtFontSize)
        }

        SettingRow {
            visible: Appearance.qtFont !== ""
            sub: true
            label: "Qt font size"
            changed: Appearance.changed("qtFontSize")
            onReset: Appearance.revert("qtFontSize")

            ChoiceButtons {
                choices: [9, 10, 11, 12, 13, 14]
                current: Appearance.qtFontSize
                onChosen: size => Appearance.setQtFont(Appearance.qtFont, size)
            }
        }
    }

    SettingsGroup {
        title: "Colours"

        ListPicker {
            label: "Colour scheme"
            changed: !ShellSettings.isDefault("colourSource")
            onReset: ShellSettings.reset("colourSource")
            description: "Used by the shell, kitty, window borders and the lock and login screens. From the wallpaper, it changes with it."
            choices: ColourScheme.sources.map(source => ColourScheme.label(source))
            current: ColourScheme.label(ShellSettings.colourSource)
            onPicked: value => ShellSettings.colourSource = ColourScheme.sources.find(source => ColourScheme.label(source) === value)
        }

        // The scheme: background, text, then the terminal's colours; spaced from the divider
        // above like a row's text
        Row {
            x: 16
            spacing: 6
            topPadding: 14
            bottomPadding: 16

            Repeater {
                model: ColourScheme.current ? [ColourScheme.current.background, ColourScheme.current.foreground, ColourScheme.current.accent, ...ColourScheme.current.colors.slice(1, 7)] : []

                Rectangle {
                    required property string modelData

                    width: 28
                    height: 28
                    radius: 14
                    color: modelData
                    border.width: 1
                    border.color: Theme.surface
                }
            }
        }
    }

    SettingsGroup {
        title: "More"

        SettingRow {
            label: "Desktop file chooser in Qt apps"
            changed: Appearance.changed("portalDialogs")
            onReset: Appearance.revert("portalDialogs")
            description: "Qt apps open files with the same dark chooser as everything else, rather than Qt's own. Apps pick it up when next opened."

            Toggle {
                checked: Appearance.portalDialogs
                onToggled: Appearance.setPortalDialogs(!checked)
            }
        }

        SettingRow {
            label: "Wallpaper"

            PanelButton {
                icon: "\u{F0E09}"
                label: "Choose…"
                onClicked: Exec.run("qs ipc call launcher wallpaper")
            }
        }
    }

    SettingsGroup {
        title: "Lock and login screens"

        SettingRow {
            id: faceRow
            label: "Picture"
            description: LockShare.shared ? "Pictures from ~/Pictures/profile-pictures. The wallpaper and colours follow too." : "Pictures from ~/Pictures/profile-pictures. The login screen follows once setup has run."
            expandable: true
            expanded: PanelState.isOpen("settings", "faces")
            onExpandToggled: {
                PanelState.toggle("settings", "faces");
                LockShare.refresh();
            }

            Avatar {
                path: LockShare.face
                size: 40
            }
        }

        Flow {
            visible: faceRow.expanded
            x: 16
            width: parent.width - 32
            spacing: 12
            bottomPadding: 16

            Repeater {
                model: LockShare.faces

                Avatar {
                    required property string modelData

                    path: modelData
                    size: 72
                    selected: modelData === LockShare.face
                    clickable: true
                    onClicked: LockShare.setFace(modelData)
                }
            }

            PanelText {
                visible: LockShare.faces.length === 0
                text: "No pictures there yet."
                dim: true
            }
        }

        SettingRow {
            label: "Preview"
            description: "The lock screen in a window, without locking."

            PanelButton {
                icon: "\u{F033E}"
                label: "Preview"
                onClicked: Exec.run("qs ipc call lock preview")
            }
        }
    }

    // A round picture, ringed in the accent colour when it's the one in use
    component Avatar: Item {
        id: avatar

        property string path
        property int size: 40
        property bool selected: false
        property bool clickable: false
        signal clicked

        width: size
        height: size

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: avatar.selected ? Theme.accent : mouse.containsMouse ? Theme.subtext : "transparent"
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.surface

            Image {
                anchors.fill: parent
                source: avatar.path !== "" ? `file://${avatar.path}` : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: avatar.size * 2
                sourceSize.height: avatar.size * 2
                asynchronous: true
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: avatar.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: avatar.clicked()
        }
    }

    // A setting picked from a list that opens below the row, with a search box for long lists
    component ListPicker: Column {
        id: picker

        property string label
        property string description: ""
        property bool sub: false
        property var choices: []
        property string current
        property string placeholder: "Default"
        property bool open: false
        property bool changed: false
        signal picked(string value)
        signal reset

        // Open again after a restart if it was before (RestartState)
        onOpenChanged: RestartState.setPicker(label, open)
        Component.onCompleted: {
            if (RestartState.pickerOpen(label)) {
                open = true;
                list.setExpanded(true);
            }
        }

        readonly property bool searchable: choices.length > 15
        readonly property var shown: {
            const query = search.text.trim().toLowerCase();
            return (query === "" ? choices : choices.filter(c => c.toLowerCase().includes(query))).slice(0, 200);
        }

        width: parent.width

        SettingRow {
            sub: picker.sub
            label: picker.label
            description: picker.description
            changed: picker.changed
            onReset: picker.reset()

            PanelButton {
                width: 240
                label: picker.current || picker.placeholder
                icon: picker.open ? "\u{F077}" : "\u{F078}"
                highlighted: picker.open
                onClicked: {
                    picker.open = !picker.open;
                    if (picker.open) {
                        search.text = "";
                        list.setExpanded(true);
                        if (picker.searchable)
                            Qt.callLater(search.focusInput);
                    }
                }
            }
        }

        Column {
            visible: picker.open
            x: 16
            width: parent.width - 32
            spacing: 6
            bottomPadding: 12

            TextField {
                id: search
                visible: picker.searchable
                width: parent.width
                placeholder: "Search…"
            }

            DropdownList {
                id: list
                width: parent.width
                maxHeight: 240
                items: picker.shown.map(choice => ({ label: choice, selected: choice === picker.current, value: choice }))
                onChosen: item => {
                    picker.picked(item.value);
                    picker.open = false;
                }
            }
        }
    }

    // Like ListPicker, but the choices open as tiles with pictures of each (`pictures` gives a
    // choice's image files); the current one's pictures also show beside the button. `cursors`
    // shows each picture on a dark and a light background.
    component GalleryPicker: Column {
        id: gallery

        property string label
        property string description: ""
        property var choices: []
        property string current
        property var pictures: name => []
        property bool cursors: false
        // How a choice's name shows
        property var format: name => name
        property bool open: false
        property bool changed: false
        signal picked(string value)
        signal reset

        // Open again after a restart if it was before (RestartState)
        onOpenChanged: RestartState.setPicker(label, open)
        Component.onCompleted: open = RestartState.pickerOpen(label)

        width: parent.width

        SettingRow {
            label: gallery.label
            description: gallery.description
            changed: gallery.changed
            onReset: gallery.reset()

            Row {
                spacing: 12

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: gallery.pictures(gallery.current).slice(0, gallery.cursors ? 3 : 4)

                        Image {
                            required property string modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            sourceSize.width: 44
                            sourceSize.height: 44
                            fillMode: Image.PreserveAspectFit
                            source: `file://${modelData}`
                            asynchronous: true
                        }
                    }
                }

                PanelButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 240
                    label: gallery.current ? gallery.format(gallery.current) : "Default"
                    icon: gallery.open ? "\u{F077}" : "\u{F078}"
                    highlighted: gallery.open
                    onClicked: gallery.open = !gallery.open
                }
            }
        }

        Flow {
            visible: gallery.open
            x: 16
            width: parent.width - 32
            spacing: 10
            bottomPadding: 16

            Repeater {
                model: gallery.open ? gallery.choices : []

                Rectangle {
                    id: tile

                    required property string modelData
                    readonly property bool selected: modelData === gallery.current
                    readonly property var shown: gallery.pictures(modelData)

                    width: 200
                    height: 96
                    radius: Theme.radius
                    color: tileMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.width: selected ? 2 : 0
                    border.color: Theme.accent

                    // Icons in a row; cursors twice, on dark then light
                    Column {
                        x: 10
                        y: 10
                        width: parent.width - 20
                        spacing: 0

                        Repeater {
                            model: gallery.cursors ? ["#1e1e1e", "#f2f2f2"] : [""]

                            Rectangle {
                                id: strip

                                required property string modelData

                                width: parent.width
                                height: gallery.cursors ? 25 : 50
                                radius: gallery.cursors ? 0 : 6
                                color: modelData === "" ? "transparent" : modelData

                                Row {
                                    anchors.centerIn: parent
                                    spacing: gallery.cursors ? 22 : 6

                                    Repeater {
                                        model: tile.shown

                                        Image {
                                            required property string modelData
                                            width: gallery.cursors ? 22 : 28
                                            height: width
                                            sourceSize.width: width * 2
                                            sourceSize.height: height * 2
                                            fillMode: Image.PreserveAspectFit
                                            source: `file://${modelData}`
                                            asynchronous: true
                                        }
                                    }
                                }
                            }
                        }

                        PanelText {
                            visible: tile.shown.length === 0
                            text: Object.keys(gallery.cursors ? Appearance.cursorPreviews : Appearance.iconPreviews).length === 0 ? "Loading…" : "No preview"
                            dim: true
                        }
                    }

                    PanelText {
                        x: 10
                        y: 68
                        width: parent.width - 20
                        elide: Text.ElideRight
                        text: (tile.selected ? "\u{F012C} " : "") + gallery.format(tile.modelData)
                        color: tile.selected ? Theme.accent : Theme.text
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: gallery.picked(tile.modelData)
                    }
                }
            }
        }
    }
}

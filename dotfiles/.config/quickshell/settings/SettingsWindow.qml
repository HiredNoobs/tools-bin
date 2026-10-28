import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// The settings app (Super+I): an ordinary window Hyprland manages, with a sidebar of sections
// and a search box that filters them. Opened at a section with `qs ipc call settings open
// <name>`, e.g. from a panel's link. Made when opened and destroyed when closed (see shell.qml).
FloatingWindow {
    id: root

    // The section shown, by name
    property string page: "shell"
    signal pageRequested(string name)

    // Each section, with its page (a file beside this one)
    readonly property var sections: [
        { name: "sound", file: "SoundPage.qml", title: "Sound", icon: "\u{F057E}", keywords: "audio volume output input microphone speakers headphones devices apps pavucontrol" },
        { name: "network", file: "NetworkPage.qml", title: "Network", icon: "\u{F05A9}", keywords: "wifi wi-fi wireless wired ethernet internet ip dns nm-connection-editor" },
        { name: "bluetooth", file: "BluetoothPage.qml", title: "Bluetooth", icon: "\u{F00AF}", keywords: "devices pair headphones blueman" },
        { name: "displays", file: "DisplaysPage.qml", title: "Displays", icon: "\u{F0379}", keywords: "monitors screens resolution refresh rate scale arrangement nightlight brightness" },
        { name: "input", file: "InputPage.qml", title: "Keyboard and mouse", icon: "\u{F030C}", keywords: "keyboard layout repeat mouse pointer speed touchpad scrolling tap" },
        { name: "power", file: "PowerPage.qml", title: "Power and idle", icon: "\u{F0425}", keywords: "idle lock screen off suspend sleep lid battery power profile hypridle" },
        { name: "apps", file: "DefaultAppsPage.qml", title: "Default apps", icon: "\u{F003B}", keywords: "default applications open with browser email mail files folders text editor images video music audio pdf mime xdg-open mimeapps" },
        { name: "appearance", file: "AppearancePage.qml", title: "Appearance", icon: "\u{F03D8}", keywords: "theme gtk qt kvantum icons cursor fonts wallpaper nwg-look qt6ct avatar picture profile lock login sddm" },
        { name: "shell", file: "ShellPage.qml", title: "Shell", icon: "\u{F0493}", keywords: "bar panels launcher attached control centre notifications pop-ups quickshell" }
    ]
    readonly property var current: sections.find(section => section.name === page) ?? sections[0]

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var shownSections: query === "" ? sections : sections.filter(section => `${section.title} ${section.keywords}`.toLowerCase().includes(query))

    title: "Settings"
    implicitWidth: 1000
    implicitHeight: 680
    minimumSize: Qt.size(760, 480)
    color: Theme.background

    // Sidebar
    Rectangle {
        id: sidebar
        width: 250
        height: parent.height
        color: Theme.surface

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // Up/Down step through the sections shown (from the first or last when the section
            // open isn't among them), Enter opens the first match (Esc: below)
            SearchField {
                id: search
                width: parent.width
                height: 38
                pixelSize: Theme.panelFontSize
                placeholder: "Search settings…"
                startFocused: true
                onAccepted: {
                    if (root.shownSections.length > 0)
                        root.pageRequested(root.shownSections[0].name);
                }
                onKeyPressed: event => {
                    const shown = root.shownSections;
                    const index = shown.findIndex(section => section.name === root.page);
                    if (shown.length === 0 || (event.key !== Qt.Key_Down && event.key !== Qt.Key_Up))
                        return;
                    if (event.key === Qt.Key_Down)
                        root.pageRequested(shown[(index + 1) % shown.length].name);
                    else
                        root.pageRequested(shown[index < 0 ? shown.length - 1 : (index - 1 + shown.length) % shown.length].name);
                    event.accepted = true;
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.shownSections

                    ListRow {
                        required property var modelData
                        width: parent.width
                        icon: modelData.icon
                        label: modelData.title
                        selected: modelData.name === root.page
                        onClicked: root.pageRequested(modelData.name)
                    }
                }

                PanelText {
                    visible: root.shownSections.length === 0
                    leftPadding: 10
                    text: "No settings match"
                    dim: true
                }
            }
        }
    }

    // The section
    Item {
        x: sidebar.width
        width: parent.width - sidebar.width
        height: parent.height

        Flickable {
            id: content

            // Scroll position to go back to after a restart (RestartState), -1 when none: tried
            // again as the page grows (lists and pictures arrive after it's built)
            property real restoreY: -1

            function applyRestore(): void {
                if (restoreY >= 0)
                    contentY = Math.max(0, Math.min(restoreY, contentHeight - height));
            }

            anchors.fill: parent
            contentHeight: pageColumn.implicitHeight + 56
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            onContentYChanged: RestartState.scrollY = contentY
            onContentHeightChanged: applyRestore()

            Timer {
                id: restoreTimer
                interval: 3000
                onTriggered: {
                    content.restoreY = -1;
                    RestartState.restored = null;
                }
            }

            Column {
                id: pageColumn
                x: Math.max(28, (content.width - width) / 2)
                y: 28
                width: Math.min(760, content.width - 56)
                spacing: 24

                PanelText {
                    text: root.current.title
                    font.pixelSize: Theme.fontSize + 9
                }

                Loader {
                    id: pageLoader
                    width: parent.width
                    source: Qt.resolvedUrl(root.current.file)
                }
            }
        }

        ScrollIndicator {
            flickable: content
            thickness: 4
            margin: 4
        }
    }

    // Esc goes back to the search box from a page, then clears the search, then closes the
    // window; Ctrl+F goes to the search box
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (!search.inputFocus)
                search.focusInput();
            else if (search.text !== "")
                search.text = "";
            else
                root.visible = false;
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            search.focusInput();
            search.selectAll();
        }
    }

    // Back to the top when switching section
    onPageChanged: {
        content.contentY = 0;
        RestartState.page = page;
    }

    Component.onCompleted: {
        RestartState.windowOpen = true;
        RestartState.page = page;
        // Reopened after a restart: back where it was, once the page has been built
        if (RestartState.restored) {
            content.restoreY = RestartState.restored.scrollY ?? 0;
            Qt.callLater(content.applyRestore);
            restoreTimer.start();
        }
    }

    // Lists opened in it close with it (DropdownRow); other open sections stay for the session
    Component.onDestruction: {
        RestartState.windowClosed();
        const keys = Object.keys(PanelState.open.settings ?? {});
        PanelState.prune("settings", keys.filter(key => !key.startsWith("picker:")));
    }
}

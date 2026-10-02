import QtQuick
import Quickshell
import qs
import qs.components

// The settings app (Super+I): an ordinary window Hyprland manages, with a sidebar of sections
// and a search box that filters them. Opened at a section with `qs ipc call settings open
// <name>`, e.g. from a panel's link. Made when opened and destroyed when closed (see shell.qml).
FloatingWindow {
    id: root

    // The section shown, by name
    property string page: "shell"
    signal pageRequested(string name)

    readonly property var sections: [
        { name: "sound", title: "Sound", icon: "\u{F057E}", keywords: "audio volume output input microphone speakers headphones devices apps pavucontrol" },
        { name: "network", title: "Network", icon: "\u{F05A9}", keywords: "wifi wi-fi wireless wired ethernet internet ip dns nm-connection-editor" },
        { name: "bluetooth", title: "Bluetooth", icon: "\u{F00AF}", keywords: "devices pair headphones blueman" },
        { name: "displays", title: "Displays", icon: "\u{F0379}", keywords: "monitors screens resolution refresh rate scale arrangement nightlight brightness" },
        { name: "input", title: "Keyboard and mouse", icon: "\u{F030C}", keywords: "keyboard layout repeat mouse pointer speed touchpad scrolling tap" },
        { name: "power", title: "Power and idle", icon: "\u{F0425}", keywords: "idle lock screen off suspend sleep lid battery power profile hypridle" },
        { name: "appearance", title: "Appearance", icon: "\u{F03D8}", keywords: "theme gtk qt kvantum icons cursor fonts wallpaper nwg-look qt6ct" },
        { name: "shell", title: "Shell", icon: "\u{F0493}", keywords: "bar panels launcher attached control centre notifications pop-ups quickshell" }
    ]
    // Pages built so far; the others show what's coming
    readonly property var pages: ({
            "sound": soundPage,
            "network": networkPage,
            "bluetooth": bluetoothPage,
            "displays": displaysPage,
            "shell": shellPage
        })
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

            Rectangle {
                width: parent.width
                height: 38
                radius: Theme.radius
                color: Theme.surface

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    text: "\u{F0349}"
                    dim: true
                }

                TextInput {
                    id: search
                    anchors.verticalCenter: parent.verticalCenter
                    x: 40
                    width: parent.width - 54
                    color: Theme.text
                    selectionColor: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelFontSize
                    clip: true
                    focus: true

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Search settings…"
                        dim: true
                    }

                    // Up/Down step through the sections shown, Enter opens the first match,
                    // Esc clears the search
                    Keys.onPressed: event => {
                        const shown = root.shownSections;
                        const index = shown.findIndex(section => section.name === root.page);
                        switch (event.key) {
                        case Qt.Key_Escape:
                            search.text = "";
                            break;
                        case Qt.Key_Down:
                            if (shown.length > 0)
                                root.pageRequested(shown[(index + 1) % shown.length].name);
                            break;
                        case Qt.Key_Up:
                            if (shown.length > 0)
                                root.pageRequested(shown[(index - 1 + shown.length) % shown.length].name);
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            if (shown.length > 0)
                                root.pageRequested(shown[0].name);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
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
            anchors.fill: parent
            contentHeight: pageColumn.implicitHeight + 56
            boundsBehavior: Flickable.StopAtBounds
            clip: true

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
                    sourceComponent: root.pages[root.current.name] ?? comingSoon
                }
            }
        }

        // Scrollbar
        Rectangle {
            visible: content.contentHeight > content.height
            anchors.right: parent.right
            anchors.rightMargin: 4
            y: content.visibleArea.yPosition * content.height
            width: 4
            height: content.visibleArea.heightRatio * content.height
            radius: 2
            color: Theme.subtext
        }
    }

    // Back to the top when switching section
    onPageChanged: content.contentY = 0

    Component {
        id: soundPage

        SoundPage {}
    }

    Component {
        id: networkPage

        NetworkPage {}
    }

    Component {
        id: bluetoothPage

        BluetoothPage {}
    }

    Component {
        id: displaysPage

        DisplaysPage {}
    }

    Component {
        id: shellPage

        ShellPage {}
    }

    Component {
        id: comingSoon

        PanelText {
            text: "Coming in a later stage."
            dim: true
        }
    }
}

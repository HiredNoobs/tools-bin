pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    readonly property color background: scheme.special.background
    readonly property color text: scheme.special.foreground || scheme.colors.color7
    readonly property color accent: scheme.special.accent || scheme.colors.color9

    readonly property color charging: "#26A65B"
    readonly property color warning: "#ffbe61"
    readonly property color critical: "#f53c3c"

    // Bar and panels share one background so attached panels look like part of the bar
    readonly property color panelBackground: Qt.alpha(background, 0.97)
    readonly property color surface: Qt.alpha(text, 0.08)
    readonly property color surfaceHover: Qt.alpha(accent, 0.2)
    readonly property color subtext: Qt.alpha(text, 0.6)

    // Wifi signal icons, weakest to strongest
    readonly property var wifiIcons: ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"]

    function wifiIcon(strength: real): string {
        return wifiIcons[Math.max(0, Math.min(4, Math.floor(strength * 5)))];
    }

    readonly property string fontFamily: "CodeNewRoman Nerd Font Propo"
    readonly property int fontSize: 15
    readonly property int panelFontSize: 14
    readonly property int barHeight: 34
    // Layout switches, set in the settings window (see ShellSettings)
    readonly property bool controlCentre: ShellSettings.controlCentre
    // Attaching to the bar: a master switch, then each kind of drop-down. Detached, panels
    // float just below their icon, the launcher's menus open in the middle of the screen,
    // notification pop-ups float in the top-right corner and the volume/brightness pop-up floats
    // near the bottom.
    readonly property bool panelsAttached: ShellSettings.attachToBar && ShellSettings.attachPanels
    readonly property bool launcherAttached: ShellSettings.attachToBar && ShellSettings.attachLauncher
    readonly property bool popupsAttached: ShellSettings.attachToBar && ShellSettings.attachPopups
    readonly property bool osdAttached: ShellSettings.attachToBar && ShellSettings.attachOsd
    // Between the bar and anything floating below it
    readonly property int panelGap: 8
    readonly property int panelMaxHeight: 700
    readonly property int panelPadding: 14
    readonly property int radius: 10
    readonly property int animDuration: 300
    readonly property int panelAnimDuration: 250

    // The colour scheme in colours.json (ColourScheme writes it), reloaded when it changes, and
    // when ColourScheme has written it (on a first start it isn't there to watch yet)
    function reloadColours(): void {
        colourFile.reload();
    }

    FileView {
        id: colourFile
        path: Quickshell.env("HOME") + "/.cache/colours/colours.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: scheme

            property JsonObject special: JsonObject {
                property string background: "#282828"
                property string foreground: ""
                property string accent: ""
            }
            property JsonObject colors: JsonObject {
                property string color7: "#d5c4a1"
                property string color9: "#fb4934"
            }
        }
    }
}

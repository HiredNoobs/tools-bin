pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shell options changed from the settings window (Shell page), saved in Quickshell's state
// folder so they survive restarts (not in the repo, not synced between machines). The defaults
// are below; Theme and the services read them from here, so changes apply straight away.
Singleton {
    id: root

    // Right-hand icons open one tabbed control centre (true) or their own panels (false)
    property alias controlCentre: adapter.controlCentre
    // Drop-downs joined to the bottom of the bar; off, none are (see Theme)
    property alias attachToBar: adapter.attachToBar
    // Which ones, while attachToBar is on: the bar icons' panels, the launcher's menus
    // (Super+Space, Print, the wallpaper picker) and notification pop-ups
    property alias attachPanels: adapter.attachPanels
    property alias attachLauncher: adapter.attachLauncher
    property alias attachPopups: adapter.attachPopups
    // How long a notification pop-up stays up, unless it asks for longer
    property alias popupSeconds: adapter.popupSeconds
    // Pop-ups on screen at once; more wait their turn
    property alias maxPopups: adapter.maxPopups

    FileView {
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // Saved whenever a setting changes
        onAdapterUpdated: writeAdapter()
        // First run: save the defaults
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property bool controlCentre: true
            property bool attachToBar: true
            property bool attachPanels: true
            property bool attachLauncher: true
            property bool attachPopups: true
            property int popupSeconds: 5
            property int maxPopups: 3
        }
    }
}

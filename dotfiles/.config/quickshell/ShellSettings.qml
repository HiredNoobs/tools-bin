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
    // Volume sliders in the settings window go up to 150% (software boost, may distort)
    property alias volumeBoost: adapter.volumeBoost
    // Nightlight's warmth in kelvin, and whether it follows a schedule ("HH:MM" times)
    property alias nightlightTemperature: adapter.nightlightTemperature
    property alias nightlightSchedule: adapter.nightlightSchedule
    property alias nightlightStart: adapter.nightlightStart
    property alias nightlightEnd: adapter.nightlightEnd
    // Closing the laptop lid: "suspend", "lock" or "nothing"; with another screen connected,
    // also "screen-off" (just the laptop screen)
    property alias lidAction: adapter.lidAction
    property alias lidDocked: adapter.lidDocked
    // Low battery: a warning at one level, and "nothing", "suspend" or "poweroff" at another
    property alias batteryWarn: adapter.batteryWarn
    property alias batteryCritical: adapter.batteryCritical
    property alias batteryCriticalAction: adapter.batteryCriticalAction

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
            property bool volumeBoost: false
            property int nightlightTemperature: 5000
            property bool nightlightSchedule: false
            property string nightlightStart: "21:00"
            property string nightlightEnd: "07:00"
            property string lidAction: "suspend"
            property string lidDocked: "screen-off"
            property int batteryWarn: 15
            property int batteryCritical: 5
            property string batteryCriticalAction: "nothing"
        }
    }
}

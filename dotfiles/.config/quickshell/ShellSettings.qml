pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shell options changed from the settings window (Shell page), saved in Quickshell's state
// folder so they survive restarts (not in the repo, not synced between machines). The defaults
// are below; Theme and the services read them from here, so changes apply straight away.
Singleton {
    id: root

    // Every option's default, for first runs and the settings window's ↺ buttons
    readonly property var defaults: ({
            controlCentre: true,
            attachToBar: true,
            attachPanels: true,
            attachLauncher: true,
            attachPopups: true,
            attachOsd: true,
            popupSeconds: 5,
            maxPopups: 3,
            volumeBoost: false,
            nightlightTemperature: 5000,
            nightlightSchedule: false,
            nightlightStart: "21:00",
            nightlightEnd: "07:00",
            lidAction: "suspend",
            lidDocked: "screen-off",
            batteryWarn: 15,
            batteryCritical: 5,
            batteryCriticalAction: "nothing",
            colourSource: "gruvbox",
            clipboardHistory: true,
            keepAwake: false,
            presetCursors: false
        })

    function isDefault(key: string): bool {
        return root[key] === defaults[key];
    }

    function reset(key: string): void {
        root[key] = defaults[key];
    }

    // Right-hand icons open one tabbed control centre (true) or their own panels (false)
    property alias controlCentre: adapter.controlCentre
    // Drop-downs joined to the bottom of the bar; off, none are (see Theme)
    property alias attachToBar: adapter.attachToBar
    // Which ones, while attachToBar is on: the bar icons' panels, the launcher's menus
    // (Super+Space, Print, the wallpaper picker) and notification pop-ups
    property alias attachPanels: adapter.attachPanels
    property alias attachLauncher: adapter.attachLauncher
    property alias attachPopups: adapter.attachPopups
    // The volume and brightness pop-up: under the bar, or floating near the bottom of the screen
    property alias attachOsd: adapter.attachOsd
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
    // The colour scheme: one of ColourScheme's palettes, or "wallpaper" (made from it)
    property alias colourSource: adapter.colourSource
    // Keep what's copied for the Super+V menu (see Clipboard)
    property alias clipboardHistory: adapter.clipboardHistory
    // Keep awake (see KeepAwake), kept on through restarts until switched off
    property alias keepAwake: adapter.keepAwake
    // Appearance presets also switch to a cursor that suits them (see Presets)
    property alias presetCursors: adapter.presetCursors

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

            property bool controlCentre: root.defaults.controlCentre
            property bool attachToBar: root.defaults.attachToBar
            property bool attachPanels: root.defaults.attachPanels
            property bool attachLauncher: root.defaults.attachLauncher
            property bool attachPopups: root.defaults.attachPopups
            property bool attachOsd: root.defaults.attachOsd
            property int popupSeconds: root.defaults.popupSeconds
            property int maxPopups: root.defaults.maxPopups
            property bool volumeBoost: root.defaults.volumeBoost
            property int nightlightTemperature: root.defaults.nightlightTemperature
            property bool nightlightSchedule: root.defaults.nightlightSchedule
            property string nightlightStart: root.defaults.nightlightStart
            property string nightlightEnd: root.defaults.nightlightEnd
            property string lidAction: root.defaults.lidAction
            property string lidDocked: root.defaults.lidDocked
            property int batteryWarn: root.defaults.batteryWarn
            property int batteryCritical: root.defaults.batteryCritical
            property string batteryCriticalAction: root.defaults.batteryCriticalAction
            property string colourSource: root.defaults.colourSource
            property bool clipboardHistory: root.defaults.clipboardHistory
            property bool keepAwake: root.defaults.keepAwake
            property bool presetCursors: root.defaults.presetCursors
        }
    }
}

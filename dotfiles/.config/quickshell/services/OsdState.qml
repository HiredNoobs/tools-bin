pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs

// The on-screen display for the volume, mic mute and brightness keys (keybinds.lua calls
// `qs ipc call osd …`, see shell.qml). The change is made here, so volume keeps to Settings ›
// Sound's 100% limit, then shown until 1.5 s after the last press: hanging under the bar
// (bar/OsdBar.qml) or floating near the bottom of the screen (osd/Osd.qml), per
// Theme.osdAttached. Panel sliders don't show it.
Singleton {
    id: root

    // "volume", "mic" or "brightness"
    property string kind: "volume"
    property bool shown: false
    // The screen it shows on
    property string targetScreen: ""
    // The screen whose brightness changed last: an external one (ExternalBrightness) or the laptop's
    property string brightnessScreen: ""

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real maxVolume: ShellSettings.volumeBoost ? 1.5 : 1
    readonly property real step: 0.05

    // Brightness has no mute
    readonly property bool muted: kind === "volume" ? (sink?.audio?.muted ?? false) : kind === "mic" ? (source?.audio?.muted ?? false) : false
    readonly property real level: {
        if (kind === "brightness")
            return ExternalBrightness.display(brightnessScreen) ? ExternalBrightness.level(brightnessScreen) : Brightness.fraction;
        return (kind === "mic" ? source : sink)?.audio?.volume ?? 0;
    }
    // Where the bar fills to: volume can go to 150% with boosting allowed
    readonly property real full: kind === "volume" ? maxVolume : 1
    readonly property string icon: {
        if (kind === "brightness")
            return "\u{F00DF}";
        if (kind === "mic")
            return muted ? "\u{F131}" : "\u{F130}";
        return muted ? "\u{EEE8}" : "\u{F028}";
    }

    function show(kind: string, screen: string): void {
        root.kind = kind;
        targetScreen = screen;
        shown = true;
        hideTimer.restart();
    }

    function focusedScreen(): string {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    // "up", "down" or "mute"; a step up also unmutes. Anything else does nothing
    function volume(direction: string): void {
        const audio = sink?.audio;
        if (!audio || !["up", "down", "mute"].includes(direction))
            return;
        if (direction === "mute") {
            audio.muted = !audio.muted;
        } else {
            const next = audio.volume + (direction === "up" ? step : -step);
            audio.volume = Math.max(0, Math.min(maxVolume, Math.round(next * 100) / 100));
            if (direction === "up")
                audio.muted = false;
        }
        show("volume", focusedScreen());
    }

    function mic(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
        show("mic", focusedScreen());
    }

    // The focused screen if it's an external one with DDC (ExternalBrightness), otherwise the
    // laptop's; shown on the screen that changed
    function brightness(direction: string): void {
        if (direction !== "up" && direction !== "down")
            return;
        const delta = direction === "up" ? step : -step;
        const focused = focusedScreen();
        if (ExternalBrightness.display(focused)) {
            ExternalBrightness.set(focused, ExternalBrightness.level(focused) + delta);
            brightnessScreen = focused;
            show("brightness", focused);
            return;
        }
        if (!Brightness.available)
            return;
        Brightness.set(Brightness.fraction + delta);
        brightnessScreen = Quickshell.screens.find(s => s.name.startsWith("eDP"))?.name ?? focusedScreen();
        show("brightness", brightnessScreen);
    }

    // Created on first use, so the backlight and monitors have been read before the first key
    Component.onCompleted: {
        Brightness.available;
        ExternalBrightness.available;
    }

    // Needed to change the devices' volumes
    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node)
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }
}

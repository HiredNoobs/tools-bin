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

    // Brightness keys held down (keybinds.lua binds the press and the release). Laptop keys
    // don't report a hold: the firmware sends a press with its release, again after ~485 ms
    // and then every ~245 ms. Each press is a "tick" of the hold; a keyboard that does report
    // a hold gets ticks at the same pace from a timer while the key is down. The longer the
    // ticks keep coming, the more 5% steps each one makes, spread over the time until the next:
    // 1, 1, 2, 2, 3, 3, then 4 (0-100% in about 2 s). After letting go, only the last tick's
    // steps can still run. A hold stops at the end of the range, and 5 s after the press whatever
    // happens (a press whose release came first and was missed would otherwise run on).
    property string holding: ""
    property int ticks: 0
    property real lastPress: 0
    property real lastTick: 0
    property real lastRelease: 0
    property bool keyDown: false

    function holdBrightness(direction: string): void {
        const now = Date.now();
        // A new press after a pause, or the other way: a fresh start
        if (direction !== holding || now - lastTick > 600) {
            holding = direction;
            ticks = 0;
        }
        lastPress = now;
        // Its release arrived first (they can swap on the way here): not held
        keyDown = now - lastRelease > 30;
        if (tick() && keyDown) {
            downTimer.interval = 485;
            downTimer.restart();
        }
    }

    function releaseBrightness(): void {
        lastRelease = Date.now();
        keyDown = false;
        downTimer.stop();
    }

    // False once there's nothing left to change (the end of the range)
    function tick(): bool {
        ticks += 1;
        lastTick = Date.now();
        const steps = ticks <= 2 ? 1 : ticks <= 4 ? 2 : ticks <= 6 ? 3 : 4;
        stepTimer.stop();
        if (!stepOnce())
            return false;
        stepTimer.left = steps - 1;
        stepTimer.interval = Math.floor(240 / steps);
        if (stepTimer.left > 0)
            stepTimer.start();
        return true;
    }

    // One step the way it's held; false at the end
    function stepOnce(): bool {
        const before = level;
        brightness(holding);
        return level !== before;
    }

    // The rest of a tick's steps
    Timer {
        id: stepTimer

        property int left: 0

        repeat: true
        onTriggered: {
            left -= 1;
            if (!root.stepOnce() || left <= 0)
                stop();
        }
    }

    // Ticks for a key that's really held down, at the firmware's pace
    Timer {
        id: downTimer
        repeat: true
        onTriggered: {
            interval = 245;
            if (!root.keyDown || Date.now() - root.lastPress > 5000 || !root.tick())
                stop();
        }
    }

    // The focused screen if it's an external one with DDC (ExternalBrightness), otherwise the
    // laptop's; shown on the screen that changed
    function brightness(direction: string): void {
        if (direction !== "up" && direction !== "down")
            return;
        // To the next multiple of 5% that way, so it stays on whole steps (37% -> 35% -> 30%)
        const next = level => {
            const percent = Math.round(level * 100);
            return (direction === "up" ? Math.floor(percent / 5) * 5 + 5 : Math.ceil(percent / 5) * 5 - 5) / 100;
        };
        const focused = focusedScreen();
        if (ExternalBrightness.display(focused)) {
            ExternalBrightness.set(focused, next(ExternalBrightness.level(focused)));
            brightnessScreen = focused;
            show("brightness", focused);
            return;
        }
        if (!Brightness.available)
            return;
        // A backlight with few levels (some have under 20) can round a 5% step back to the
        // level it's on: then on to the next 5%, until it moves
        let target = next(Brightness.fraction);
        while (target > Brightness.minFraction && target < 1 && Math.round(target * Brightness.maxBrightness) === Brightness.brightness)
            target = next(target);
        Brightness.set(target);
        brightnessScreen = Quickshell.screens.find(s => Monitors.isBuiltIn(s.name))?.name ?? focusedScreen();
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

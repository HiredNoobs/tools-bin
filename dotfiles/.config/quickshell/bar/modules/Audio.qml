import QtQuick
import Quickshell.Services.Pipewire
import qs.components

// Speaker icon covering all sound; the tooltip also shows the mic.
// Left click opens the audio panel (wired up in Bar.qml), right click mutes, scroll changes volume.
BarText {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volumeFraction: sink?.audio?.volume ?? 0
    readonly property int volume: Math.round(volumeFraction * 100)

    readonly property string sinkIcon: {
        const formFactors = {
            "headphone": "\u{F025}",
            "hands-free": "\u{F025}",
            "headset": "\u{F025}",
            "phone": "\u{F095}",
            "portable": "\u{F095}",
            "car": "\u{F1B9}"
        };
        // 0 waves under 10%, 1 wave under 40%, 2 waves under 80%, 3 waves above.
        // FontAwesome has no two-wave speaker, so that one is Material Design's.
        const levels = ["\u{F026}", "\u{F027}", "\u{F057E}", "\u{F028}"];
        const level = volume < 10 ? 0 : volume < 40 ? 1 : volume < 80 ? 2 : 3;
        return formFactors[sink?.properties["device.form-factor"]] ?? levels[level];
    }

    function describe(label: string, node: PwNode): string {
        if (!node?.audio)
            return "";
        const level = `${label} ${Math.round(node.audio.volume * 100)}%`;
        return node.audio.muted ? `${level} (muted)` : level;
    }

    function setVolume(value: real): void {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    visible: sink !== null
    text: muted ? "\u{EEE8}" : sinkIcon
    tooltip: [describe("Volume", sink), describe("Microphone", source)].filter(line => line !== "").join("\n")

    onRightClicked: {
        if (sink?.audio)
            sink.audio.muted = !muted;
    }
    onScrolledUp: setVolume(volumeFraction + 0.01)
    onScrolledDown: setVolume(volumeFraction - 0.01)

    // Needed for the nodes' audio properties to be populated
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}

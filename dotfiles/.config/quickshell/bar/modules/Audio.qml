import QtQuick
import Quickshell.Services.Pipewire
import qs.components

// Speaker icon showing mute and volume level.
// Left click opens the audio panel (wired up in Bar.qml).
BarText {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)

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

    visible: sink !== null
    text: muted ? "\u{EEE8}" : sinkIcon

    // Needed for the node's audio properties to be populated
    PwObjectTracker {
        objects: [root.sink]
    }
}

import QtQuick
import Quickshell.Services.Pipewire
import qs.components
import qs.services

// Default speaker, or the default microphone when `source` is set
BarText {
    id: root

    property bool source: false

    readonly property PwNode node: source ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property int volume: Math.round((node?.audio?.volume ?? 0) * 100)
    readonly property string pamixerTarget: source ? "--default-source " : ""

    readonly property string sinkIcon: {
        const formFactors = {
            "headphone": "\u{F025}",
            "hands-free": "\u{F025}",
            "headset": "\u{F025}",
            "phone": "\u{F095}",
            "portable": "\u{F095}",
            "car": "\u{F1B9}"
        };
        const levels = ["\u{F026}", "\u{F027}", "\u{F027}", "\u{F028}"];
        return formFactors[node?.properties["device.form-factor"]] ?? levels[Math.min(levels.length - 1, Math.floor(volume / 25))];
    }

    visible: node !== null
    text: source ? `${muted ? "\u{F131}" : "\u{F130}"} ${volume}%` : `${muted ? "\u{EEE8}" : sinkIcon} ${volume}%`
    tooltip: source ? (node?.description ?? "") : ""

    onLeftClicked: Exec.run(`pamixer ${pamixerTarget}-t`)
    onScrolledUp: Exec.run(`pamixer ${pamixerTarget}-i ${source ? 5 : 1}`)
    onScrolledDown: Exec.run(`pamixer ${pamixerTarget}-d ${source ? 5 : 1}`)
    onRightClicked: menu.toggle()

    // Needed for the node's audio properties to be populated
    PwObjectTracker {
        objects: [root.node]
    }

    ActionMenu {
        id: menu
        target: root
        items: [
            { label: "\u{F013} Audio settings", action: () => Exec.floating(`pavucontrol -t ${root.source ? 4 : 3}`, false) }
        ]
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Outputs that exist on a sound card but are hidden behind a different card profile
// (e.g. HDMI audio while the card is on "Analog Stereo"). PipeWire only creates outputs for
// the active profile, so choosing one of these switches the card's profile.
Singleton {
    id: root

    // [{ card, profile, label, kind }]
    property var hiddenOutputs: []

    function refresh(): void {
        query.running = true;
    }

    function switchTo(output: var): void {
        Exec.run(`pactl set-card-profile '${output.card}' '${output.profile}'`);
        refreshTimer.restart();
    }

    // Best profile for a port: available, highest priority, preferring ones that keep an input
    // (so the mic keeps working)
    function bestProfile(card: var, port: var): string {
        const candidates = port.profiles
            .map(name => ({ name: name, info: card.profiles[name] }))
            .filter(p => p.info?.available && p.name !== "pro-audio");
        candidates.sort((a, b) => (b.info.sources > 0) - (a.info.sources > 0) || b.info.priority - a.info.priority);
        return candidates[0]?.name ?? "";
    }

    function parse(json: string): void {
        const outputs = [];
        for (const card of JSON.parse(json)) {
            for (const [portName, port] of Object.entries(card.ports)) {
                if (!portName.includes("output") || port.availability === "not available")
                    continue;
                // Ports of the active profile already appear as normal PipeWire outputs
                if (port.profiles.includes(card.active_profile))
                    continue;
                const profile = bestProfile(card, port);
                if (profile === "")
                    continue;
                const product = port.properties?.["device.product.name"];
                outputs.push({
                    card: card.name,
                    profile: profile,
                    label: product ? `${port.description} (${product})` : port.description,
                    kind: port.type === "HDMI" ? "HDMI / DisplayPort" : "Built-in"
                });
            }
        }
        hiddenOutputs = outputs;
    }

    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parse(text);
                } catch (e) {
                    root.hiddenOutputs = [];
                }
            }
        }
    }

    // Re-read after outputs appear or disappear (profile switches, plugging in devices)
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: root.refresh()
    }
}

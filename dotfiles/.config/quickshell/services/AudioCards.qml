pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

// Sound cards and device ports, through pactl, for what PipeWire's API doesn't cover.
// - Outputs that exist on a sound card but are hidden behind a different card profile (e.g.
//   HDMI audio while the card is on "Analog Stereo"). PipeWire only creates outputs for the
//   active profile, so choosing one of these switches the card's profile.
// - Each card's profiles and each device's ports (Speakers / Headphones…), for the settings
//   window, and moving an app's stream to another device. pactl numbers streams by their
//   PipeWire object.serial and accepts devices by node name.
// - Turning volume boost off (Settings › Sound) brings anything above 100% back to 100%.
Singleton {
    id: root

    // [{ card, profile, label, kind }]
    property var hiddenOutputs: []
    // [{ name, description, activeProfile, profiles: [{ name, description, available }] }]
    property var cards: []
    // Device node name -> { active, ports: [{ name, description, available }] }
    property var ports: ({})

    function refresh(): void {
        query.running = true;
    }

    function switchTo(output: var): void {
        setProfile(output.card, output.profile);
    }

    function setProfile(card: string, profile: string): void {
        Exec.run(`pactl set-card-profile ${Exec.quote(card)} ${Exec.quote(profile)}`);
        refreshTimer.restart();
    }

    function setPort(device: PwNode, port: string): void {
        const kind = device.isSink ? "sink" : "source";
        Exec.run(`pactl set-${kind}-port ${Exec.quote(device.name)} ${Exec.quote(port)}`);
        refreshTimer.restart();
    }

    // An app's playing (or recording) stream to another output (or input)
    function moveStream(stream: PwNode, device: PwNode): void {
        const kind = device.isSink ? "sink-input" : "source-output";
        Exec.run(`pactl move-${kind} ${stream.properties["object.serial"]} ${Exec.quote(device.name)}`);
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

    // Every device and app stream above 100% back to 100%. Volumes can only be set on tracked
    // nodes, so they're tracked for a moment first.
    property bool capping: false

    function capVolumes(): void {
        capping = true;
        capTimer.restart();
    }

    PwObjectTracker {
        objects: root.capping ? Pipewire.nodes.values.filter(node => node.audio) : []
    }

    Timer {
        id: capTimer
        interval: 300
        onTriggered: {
            for (const node of Pipewire.nodes.values) {
                if (node.audio && node.audio.volume > 1)
                    node.audio.volume = 1;
            }
            root.capping = false;
        }
    }

    Connections {
        target: ShellSettings
        function onVolumeBoostChanged() {
            if (!ShellSettings.volumeBoost)
                root.capVolumes();
        }
    }

    function parseCards(json: string): void {
        const outputs = [];
        const cards = JSON.parse(json);
        root.cards = cards.map(card => ({
                    name: card.name,
                    description: card.properties?.["device.description"] ?? card.name,
                    activeProfile: card.active_profile,
                    profiles: Object.entries(card.profiles)
                        .sort((a, b) => b[1].priority - a[1].priority)
                        .map(([name, profile]) => ({ name: name, description: profile.description, available: profile.available }))
                }));
        for (const card of cards) {
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

    function parsePorts(json: string, into: var): void {
        for (const device of JSON.parse(json)) {
            into[device.name] = {
                active: device.active_port ?? "",
                ports: device.ports.map(port => ({ name: port.name, description: port.description, available: port.availability !== "not available" }))
            };
        }
    }

    Component.onCompleted: refresh()

    // Cards, outputs and inputs in one go, one JSON document per line
    Process {
        id: query
        command: ["sh", "-c", "pactl -f json list cards; echo; pactl -f json list sinks; echo; pactl -f json list sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [cards, sinks, sources] = text.split("\n").filter(line => line.trim() !== "");
                try {
                    root.parseCards(cards);
                } catch (e) {
                    root.hiddenOutputs = [];
                    root.cards = [];
                }
                try {
                    const ports = {};
                    root.parsePorts(sinks, ports);
                    root.parsePorts(sources, ports);
                    root.ports = ports;
                } catch (e) {
                    root.ports = {};
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

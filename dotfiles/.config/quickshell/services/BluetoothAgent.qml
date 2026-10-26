pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// The Bluetooth pairing agent (scripts/bluetooth-agent.py), run for as long as the shell is.
// BlueZ asks it to confirm codes, take PINs and allow incoming pairing; each request shows as
// a pop-up (launcher/BluetoothPairing.qml, opened from shell.qml) and `answer` replies.
// Devices paired from here are trusted, as accepting a request is, so they reconnect without
// asking each time.
Singleton {
    id: root

    // The request waiting for an answer, or null:
    // { id, type: "confirm" | "authorize" | "service" | "pin" | "passkey" | "display", device,
    // path (the device's D-Bus path), code?, entered? }. "service" is a device that isn't
    // trusted using one (e.g. audio). "display" (type this code on the keyboard) needs no
    // answer (id 0): it's updated as keys are typed and goes once the pairing ends, and
    // cancelling it cancels the pairing. More that come meanwhile wait their turn behind it.
    readonly property var request: requests[0] ?? null
    property var requests: []
    // False if the agent couldn't register (e.g. bluetoothd isn't running)
    property bool ready: false
    // Paths of the devices seen pairing while they showed a code (not a property to bind to)
    property var seenPairing: ({})

    function device(path: string): var {
        return Bluetooth.devices.values.find(d => d.dbusPath === path) ?? null;
    }

    function answer(accept: bool, value: string): void {
        if (!request)
            return;
        if (request.id > 0)
            agent.write(`${request.id} ${accept ? "accept" : "reject"} ${value ?? ""}\n`);
        else if (request.type === "display" && !accept) {
            const pairing = device(request.path);
            if (pairing?.pairing)
                pairing.cancelPair();
        }
        requests = requests.slice(1);
    }

    // A code to type, again with each key typed: it replaces the one shown for that device.
    // Anything else from a device ends its code.
    function add(message: var): void {
        const index = requests.findIndex(r => r.type === "display" && r.path === message.path);
        if (message.type === "display" && index >= 0) {
            const updated = requests.slice();
            updated[index] = message;
            requests = updated;
            return;
        }
        requests = [...requests.filter(r => r.type !== "display" || r.path !== message.path), message];
    }

    // The pairing window closed: no to everything waiting
    function rejectAll(): void {
        while (request)
            answer(false, "");
    }

    Process {
        id: agent
        command: ["python3", "-I", Quickshell.shellPath("scripts/bluetooth-agent.py")]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (e) {
                    return;
                }
                switch (message.type) {
                case "ready":
                    root.ready = true;
                    break;
                case "error":
                    root.ready = false;
                    console.warn(`Bluetooth agent: ${message.message}`);
                    break;
                case "cancel":
                    root.requests = [];
                    break;
                default:
                    root.add(message);
                }
            }
        }

        // Started again if it stops (it shouldn't)
        onExited: {
            root.ready = false;
            root.requests = [];
            restart.restart();
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: agent.running = true
    }

    // A code shown goes once its device has paired, or stopped pairing (failed, or cancelled
    // on the device); BlueZ doesn't say
    Timer {
        interval: 500
        repeat: true
        running: root.requests.some(r => r.type === "display")
        onTriggered: {
            const kept = root.requests.filter(r => {
                if (r.type !== "display")
                    return true;
                const device = root.device(r.path);
                if (device?.pairing)
                    root.seenPairing[r.path] = true;
                return device && !device.paired && !(root.seenPairing[r.path] && !device.pairing);
            });
            if (kept.length !== root.requests.length) {
                for (const r of root.requests.filter(r => !kept.includes(r)))
                    delete root.seenPairing[r.path];
                root.requests = kept;
            }
        }
    }

    Instantiator {
        model: Bluetooth.devices

        Connections {
            required property BluetoothDevice modelData

            target: modelData

            function onPairedChanged(): void {
                if (modelData.paired && !modelData.trusted)
                    modelData.trusted = true;
            }
        }
    }
}

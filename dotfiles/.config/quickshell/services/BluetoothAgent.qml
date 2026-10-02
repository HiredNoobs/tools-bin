pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The Bluetooth pairing agent (scripts/bluetooth-agent.py), run for as long as the shell is.
// BlueZ asks it to confirm codes, take PINs and allow incoming pairing; each request shows as
// a pop-up (launcher/BluetoothPairing.qml, opened from shell.qml) and `answer` replies.
Singleton {
    id: root

    // The request waiting for an answer, or null:
    // { id, type: "confirm" | "authorize" | "pin" | "passkey" | "display", device, code?, entered? }
    // "display" (type this code on the keyboard) needs no answer (id 0).
    property var request: null
    // False if the agent couldn't register (e.g. bluetoothd isn't running)
    property bool ready: false

    function answer(accept: bool, value: string): void {
        if (!request)
            return;
        if (request.id > 0)
            agent.write(`${request.id} ${accept ? "accept" : "reject"} ${value ?? ""}\n`);
        request = null;
    }

    Process {
        id: agent
        command: ["python3", Quickshell.shellPath("scripts/bluetooth-agent.py")]
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
                    root.request = null;
                    break;
                default:
                    root.request = message;
                }
            }
        }

        // Started again if it stops (it shouldn't)
        onExited: {
            root.ready = false;
            root.request = null;
            restart.restart();
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: agent.running = true
    }
}

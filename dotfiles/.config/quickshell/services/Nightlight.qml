pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// hyprsunset colour temperature: 6500 K is off, anything lower is on
Singleton {
    id: root

    readonly property int offTemperature: 6500
    readonly property int warmTemperature: 5000

    property int temperature: offTemperature
    readonly property bool enabled: temperature < offTemperature

    function refresh(): void {
        query.running = true;
    }

    function setEnabled(on: bool): void {
        temperature = on ? warmTemperature : offTemperature;
        Exec.run(`hyprctl hyprsunset temperature ${temperature}`);
        refreshTimer.restart();
    }

    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim());
                if (!isNaN(value))
                    root.temperature = value;
            }
        }
    }

    // Read back the real value after a change
    Timer {
        id: refreshTimer
        interval: 300
        onTriggered: root.refresh()
    }
}

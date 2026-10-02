pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// hyprsunset colour temperature: 6500 K is off, anything lower is on. The warmth and an
// optional schedule come from the settings window (ShellSettings). On a schedule it switches
// on and off at the set times; switching it by hand in between holds until the next one.
Singleton {
    id: root

    readonly property int offTemperature: 6500
    readonly property int warmTemperature: ShellSettings.nightlightTemperature

    property int temperature: offTemperature
    readonly property bool enabled: temperature < offTemperature

    // Whether the schedule says on now, as last checked (null before the first check)
    property var scheduledOn: null

    function refresh(): void {
        query.running = true;
    }

    function setEnabled(on: bool): void {
        temperature = on ? warmTemperature : offTemperature;
        Exec.run(`hyprctl hyprsunset temperature ${temperature}`);
        refreshTimer.restart();
    }

    function minutesOf(time: string): int {
        const [hours, minutes] = time.split(":").map(Number);
        return hours * 60 + minutes;
    }

    // Inside the start-end window, which may run past midnight (21:00-07:00)
    function inSchedule(): bool {
        const now = new Date();
        const minutes = now.getHours() * 60 + now.getMinutes();
        const start = minutesOf(ShellSettings.nightlightStart);
        const end = minutesOf(ShellSettings.nightlightEnd);
        return start <= end ? minutes >= start && minutes < end : minutes >= start || minutes < end;
    }

    // Acts only when the schedule's answer changes (and on first check), so a switch by hand
    // holds until the next start or end
    function checkSchedule(): void {
        if (!ShellSettings.nightlightSchedule) {
            scheduledOn = null;
            return;
        }
        const on = inSchedule();
        if (on !== scheduledOn) {
            scheduledOn = on;
            setEnabled(on);
        }
    }

    Component.onCompleted: {
        refresh();
        checkSchedule();
    }

    Timer {
        interval: 30000
        running: ShellSettings.nightlightSchedule
        repeat: true
        onTriggered: root.checkSchedule()
    }

    Connections {
        target: ShellSettings

        // Turning the schedule on, or changing its times, applies it now
        function onNightlightScheduleChanged() {
            root.scheduledOn = null;
            root.checkSchedule();
        }
        function onNightlightStartChanged() {
            root.scheduledOn = null;
            root.checkSchedule();
        }
        function onNightlightEndChanged() {
            root.scheduledOn = null;
            root.checkSchedule();
        }
        // A new warmth shows straight away while on
        function onNightlightTemperatureChanged() {
            if (root.enabled)
                root.setEnabled(true);
        }
    }

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

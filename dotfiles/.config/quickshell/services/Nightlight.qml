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
    // The temperature last set here, until hyprsunset reports it (null then), and the tries so
    // far: at start hyprsunset may not be answering yet, so a set it didn't take is sent again
    // after 1, 2, 4 and 8 s
    property var wanted: null
    property int tries: 0

    function refresh(): void {
        query.running = true;
    }

    function setEnabled(on: bool): void {
        tries = 0;
        apply(on ? warmTemperature : offTemperature);
    }

    function apply(value: int): void {
        temperature = value;
        wanted = value;
        retryTimer.stop();
        Exec.run(`hyprctl hyprsunset temperature ${value}`);
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

    // As if checked for the first time
    function reschedule(): void {
        scheduledOn = null;
        checkSchedule();
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
            root.reschedule();
        }
        function onNightlightStartChanged() {
            root.reschedule();
        }
        function onNightlightEndChanged() {
            root.reschedule();
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
                if (root.wanted !== null && value !== root.wanted && root.tries < 4) {
                    retryTimer.interval = 1000 * Math.pow(2, root.tries++);
                    retryTimer.restart();
                    return;
                }
                root.wanted = null;
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

    Timer {
        id: retryTimer
        onTriggered: {
            if (root.wanted !== null)
                root.apply(root.wanted);
        }
    }
}

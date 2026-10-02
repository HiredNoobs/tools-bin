pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

// Low battery on a laptop (Settings › Power and idle): a notification at one level, and
// suspending or powering off at a critical one. Each happens once per time on battery.
Singleton {
    id: root

    readonly property bool discharging: Battery.present && UPower.onBattery
    readonly property int level: Battery.capacity
    property bool warned: false
    property bool acted: false

    function check(): void {
        if (!discharging) {
            warned = false;
            acted = false;
            return;
        }
        if (!warned && level <= ShellSettings.batteryWarn) {
            warned = true;
            Exec.run(`notify-send -u critical -i battery-caution "Battery low" "${level}% left. Plug in soon."`);
        }
        if (!acted && level <= ShellSettings.batteryCritical) {
            acted = true;
            if (ShellSettings.batteryCriticalAction === "suspend")
                Exec.run("systemctl suspend");
            else if (ShellSettings.batteryCriticalAction === "poweroff")
                Exec.run("systemctl poweroff");
        }
    }

    onDischargingChanged: check()
    onLevelChanged: check()
    Component.onCompleted: check()
}

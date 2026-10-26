pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property int cpuUsage: 0
    property var coreUsage: []
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property int temperature: 0
    // The CPU's sensor: the package temperature of Intel's coretemp or AMD's k10temp/zenpower,
    // else the x86_pkg_temp zone, else the first zone (thermal_zone0 is often the ACPI one,
    // which reads far below the CPU)
    property string temperaturePath: ""

    property var lastCpuTimes: []

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            if (thermal.path !== "")
                thermal.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // Lines "cpu" (total) then "cpu0".."cpuN"
            const lines = text().split("\n").filter(l => l.startsWith("cpu"));
            const times = lines.map(l => {
                const f = l.trim().split(/\s+/).slice(1).map(Number);
                const idle = f[3] + f[4];
                return { idle: idle, total: f.reduce((a, b) => a + b, 0) };
            });

            const usage = times.map((t, i) => {
                const prev = lastCpuTimes[i];
                if (!prev || t.total === prev.total)
                    return 0;
                return Math.round(100 * (1 - (t.idle - prev.idle) / (t.total - prev.total)));
            });

            lastCpuTimes = times;
            cpuUsage = usage[0];
            coreUsage = usage.slice(1);
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))[1]);
            const total = kb("MemTotal");
            memTotalGiB = total / 1048576;
            memUsedGiB = (total - kb("MemAvailable")) / 1048576;
        }
    }

    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
                case $(cat "$h/name" 2>/dev/null) in coretemp|k10temp|zenpower) [ -e "$h/temp1_input" ] && echo "$h/temp1_input" && exit ;; esac
            done
            for z in /sys/class/thermal/thermal_zone*; do
                [ "$(cat "$z/type" 2>/dev/null)" = x86_pkg_temp ] && echo "$z/temp" && exit
            done
            [ -e /sys/class/thermal/thermal_zone0/temp ] && echo /sys/class/thermal/thermal_zone0/temp
        `]
        stdout: StdioCollector {
            onStreamFinished: temperaturePath = text.trim()
        }
    }

    FileView {
        id: thermal
        path: temperaturePath
        printErrors: false
        onLoaded: temperature = Math.round(Number(text()) / 1000)
    }
}

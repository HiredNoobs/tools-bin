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

    property var lastCpuTimes: []

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
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

    FileView {
        id: thermal
        path: "/sys/class/thermal/thermal_zone0/temp"
        onLoaded: temperature = Math.round(Number(text()) / 1000)
    }
}

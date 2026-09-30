import QtQuick
import qs.components
import qs.services

BarText {
    text: `\u{F0EE0} ${SysStats.cpuUsage}%`
    tooltip: SysStats.coreUsage.map((usage, i) => `Core${i}: ${usage}%`).join("\n")
}

import QtQuick
import qs.components
import qs.services

BarText {
    text: `\u{EFC5} ${SysStats.memUsedGiB.toFixed(1)}G/${SysStats.memTotalGiB.toFixed(1)}G`
}

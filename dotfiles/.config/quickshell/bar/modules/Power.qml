import QtQuick
import qs.components
import qs.services

BarText {
    text: "\u{F011}"
    rightPadding: 10
    onLeftClicked: Exec.run(`hyprctl dispatch 'hl.dsp.exec_cmd("wlogout")'`)
}

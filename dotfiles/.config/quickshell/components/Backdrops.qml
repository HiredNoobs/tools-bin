import QtQuick
import Quickshell
import Quickshell.Wayland

// Layers over every monitor but the one a pop-up is on, so clicking them closes it (and,
// coloured, dims them): the launcher's and the overview's
Variants {
    id: root

    property bool shown: false
    // The pop-up's monitor, left uncovered
    property string exclude: ""
    property color color: "transparent"
    property string namespace: ""

    signal clicked

    model: Quickshell.screens.filter(s => s.name !== exclude)

    PanelWindow {
        required property ShellScreen modelData

        screen: modelData
        visible: root.shown
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: root.color
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: root.namespace

        MouseArea {
            anchors.fill: parent
            onClicked: root.clicked()
        }
    }
}

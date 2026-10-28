import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// Top of the control centre: a tile for each thing worth switching quickly (lit while on).
// The tabs below have the details.
Column {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property PwNode mic: Pipewire.defaultAudioSource

    spacing: 12

    // The mic's mute state needs it tracked
    PwObjectTracker {
        objects: [root.mic].filter(node => node)
    }

    // Rebuilt with every change (a click included); the tiles below are kept by label
    readonly property var toggles: [
        ...(Networking.devices.values.some(d => d.type === DeviceType.Wifi) ? [{
            icon: Networking.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}",
            label: "Wi-Fi",
            on: Networking.wifiEnabled,
            toggle: () => Networking.wifiEnabled = !Networking.wifiEnabled
        }] : []),
        ...(root.adapter ? [{
            icon: root.adapter.enabled ? "\u{F00AF}" : "\u{F00B2}",
            label: "Bluetooth",
            on: root.adapter.enabled,
            // Through rfkill too when it's blocked
            toggle: () => BluetoothControl.setPowered(!root.adapter.enabled)
        }] : []),
        {
            icon: Notifications.dnd ? "\u{F009B}" : "\u{F009A}",
            label: "Do not disturb",
            on: Notifications.dnd,
            toggle: () => Notifications.dnd = !Notifications.dnd
        },
        {
            icon: "\u{F0594}",
            label: "Night light",
            on: Nightlight.enabled,
            toggle: () => Nightlight.setEnabled(!Nightlight.enabled)
        },
        {
            icon: "\u{F0176}",
            label: "Keep awake",
            on: KeepAwake.enabled,
            toggle: () => KeepAwake.enabled = !KeepAwake.enabled
        },
        ...(root.mic?.audio ? [{
            icon: root.mic.audio.muted ? "\u{F036D}" : "\u{F036C}",
            label: "Microphone",
            on: !root.mic.audio.muted,
            toggle: () => root.mic.audio.muted = !root.mic.audio.muted
        }] : [])
    ]

    Grid {
        id: grid
        width: parent.width
        columns: 3
        spacing: 8

        Repeater {
            model: ScriptModel {
                values: root.toggles.map(toggle => toggle.label)
            }

            Rectangle {
                id: tile

                required property string modelData
                readonly property var spec: root.toggles.find(toggle => toggle.label === modelData) ?? { icon: "", label: modelData, on: false, toggle: () => {} }

                width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                height: 64
                radius: Theme.radius
                color: spec.on ? Qt.alpha(Theme.accent, mouse.containsMouse ? 0.35 : 0.25) : mouse.containsMouse ? Theme.surfaceHover : Theme.surface

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    PanelText {
                        text: tile.spec.icon
                        color: tile.spec.on ? Theme.accent : Theme.text
                        font.pixelSize: 18
                    }

                    PanelText {
                        width: parent.width
                        text: tile.spec.label
                        elide: Text.ElideRight
                        font.pixelSize: Theme.panelFontSize - 1
                        color: tile.spec.on ? Theme.accent : Theme.text
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.spec.toggle()
                }
            }
        }
    }
}

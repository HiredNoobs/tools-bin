import QtQuick
import Quickshell
import qs

// The Bluetooth pairing window (see BluetoothPairing): an ordinary window, floating and
// centred by a Hyprland rule, so it stays until the request is answered. Closing it rejects
// (shell.qml).
FloatingWindow {
    title: "Bluetooth pairing"
    implicitWidth: content.implicitWidth + 2 * Theme.panelPadding + 12
    implicitHeight: content.implicitHeight + 2 * Theme.panelPadding + 12
    color: Theme.background

    BluetoothPairing {
        id: content
        anchors.centerIn: parent
    }
}

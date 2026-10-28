pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

// How audio devices and app streams are named and limited, the same in the audio panel and
// Settings › Sound
Singleton {
    // Up to 150% when boosting is allowed (Settings › Sound)
    readonly property real maxVolume: ShellSettings.volumeBoost ? 1.5 : 1

    function nodeName(node: PwNode): string {
        return node ? node.description || node.nickname || node.name : "";
    }

    // The app a stream belongs to (each Firefox tab, and the like, is its own stream)
    function appName(stream: PwNode): string {
        return stream ? stream.properties["application.name"] ?? stream.name : "";
    }

    // Short tag for a device, e.g. to pick out Bluetooth headphones
    function deviceKind(node: PwNode): string {
        const props = node?.properties ?? {};
        if (props["device.api"] === "bluez5")
            return "Bluetooth";
        if (props["device.bus"] === "usb")
            return "USB";
        const description = (node?.description ?? "").toLowerCase();
        if (description.includes("hdmi") || description.includes("displayport"))
            return "HDMI / DisplayPort";
        return "";
    }
}

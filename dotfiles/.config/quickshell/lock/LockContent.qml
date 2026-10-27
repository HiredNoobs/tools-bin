import QtQuick
import Quickshell
import Quickshell.Networking
import qs
import qs.services

// One locked screen: LockLayout (the look, shared with the SDDM theme) fed from the shell's
// theme, battery, network, media and notifications. In the preview, the power buttons do
// nothing.
LockLayout {
    id: root

    required property var lock
    property bool preview: false

    readonly property string home: Quickshell.env("HOME")
    readonly property var devices: Networking.devices.values
    readonly property var wifiNetwork: devices.find(d => d.type === DeviceType.Wifi && d.connected)?.networks.values.find(n => n.connected) ?? null
    readonly property bool wired: devices.some(d => d.type === DeviceType.Wired && d.connected)

    wallpaper: Wallpaper.source
    background: Theme.background
    text: Theme.text
    accent: Theme.accent
    critical: Theme.critical
    warning: Theme.warning
    fontFamily: Theme.fontFamily

    userName: lock.userName
    avatars: [`file://${home}/.face`, `file://${home}/Pictures/profile-pictures/alluka.jpg`]

    // Both ways, by hand: the layout sets `password` itself, which would break a binding
    onPasswordChanged: {
        if (lock.password !== password)
            lock.password = password;
    }
    busy: lock.busy
    message: lock.message
    capsLock: lock.capsLock
    failures: lock.failures
    onSubmitted: lock.submit()
    onKeyPressed: lock.checkCaps()

    batteryPresent: Battery.present
    batteryIcon: Battery.icon
    batteryCapacity: Battery.capacity
    batteryColour: Battery.colour
    networkIcon: wifiNetwork ? Theme.wifiIcon(wifiNetwork.signalStrength) : wired ? "\u{EF09}" : "\u{EB01}"
    networkName: wifiNetwork?.name ?? (wired ? "Wired" : "Offline")
    notificationCount: Notifications.list.length

    mediaVisible: Media.hasTrack
    mediaText: [Media.player?.trackTitle ?? "", Media.player?.trackArtist ?? ""].filter(s => s !== "").join(" — ")
    mediaPlaying: Media.player?.isPlaying ?? false
    canPrevious: Media.player?.canGoPrevious ?? false
    canToggle: Media.player?.canTogglePlaying ?? false
    canNext: Media.player?.canGoNext ?? false
    onMediaPrevious: Media.player.previous()
    onMediaToggle: Media.player.togglePlaying()
    onMediaNext: Media.player.next()

    powerActions: [
        { icon: "\u{23FE}", name: "Sleep", confirm: false },
        { icon: "\u{EAD2}", name: "Reboot", confirm: true },
        { icon: "\u{23FB}", name: "Shut down", confirm: true }
    ]

    Connections {
        target: root.lock
        function onPasswordChanged() {
            if (root.password !== root.lock.password)
                root.password = root.lock.password;
        }
    }

    onPowerAction: name => {
        if (preview)
            return;
        // Locked already: sleep without locking again
        Exec.run({
            "Sleep": Exec.sleepCommand,
            "Reboot": Exec.rebootCommand,
            "Shut down": Exec.powerOffCommand
        }[name]);
    }
}

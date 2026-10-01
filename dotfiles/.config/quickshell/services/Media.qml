pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Media players (MPRIS). The one shown on the bar and at the top of the media panel follows
// playerctld (the most recently active player), the same one the media keys control.
Singleton {
    id: root

    // playerctld also appears as a player, mirroring the active one; it's left out of the
    // list but watched to know when the active player changes
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    readonly property var proxy: Mpris.players.values.find(p => p.dbusName.includes("playerctld")) ?? null

    // Bus name of playerctld's most recently active player
    property string activeName: ""

    // Without playerctld: the playing one, else the first
    readonly property var player: players.find(p => p.dbusName === activeName) ?? players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property var others: players.filter(p => p !== player)
    readonly property bool hasTrack: (player?.trackTitle ?? "") !== ""

    // Raises a player and focuses its window, switching workspace if needed. Matches the
    // window by desktop entry or any word of the player's name ("Mozilla firefox"), preferring
    // the window whose title has the track in it (the browser window with the playing tab).
    function open(target: var): void {
        if (!target)
            return;
        if (target.canRaise)
            target.raise();
        Windows.focusApp([target.desktopEntry, target.identity, ...target.identity.split(" ")], target.trackTitle);
    }

    // "1:23", or "1:02:03" past an hour
    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const h = Math.floor(total / 3600);
        const m = Math.floor(total % 3600 / 60);
        const s = String(total % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`;
    }

    // playerctld's PlayerNames is ordered most recently active first. Asking for it also
    // starts playerctld if it isn't running (it's bus-activated)
    function refreshActive(): void {
        activeQuery.running = true;
    }

    onPlayersChanged: refreshTimer.restart()
    Component.onCompleted: refreshActive()

    Process {
        id: activeQuery
        command: ["busctl", "--user", "--json=short", "get-property", "org.mpris.MediaPlayer2.playerctld", "/org/mpris/MediaPlayer2", "com.github.altdesktop.playerctld", "PlayerNames"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.activeName = JSON.parse(text).data[0] ?? "";
                } catch (e) {
                    root.activeName = "";
                }
            }
        }
    }

    // The proxy changes whenever playerctld's active player does
    Connections {
        target: root.proxy
        function onTrackTitleChanged() {
            refreshTimer.restart();
        }
        function onIdentityChanged() {
            refreshTimer.restart();
        }
        function onPlaybackStateChanged() {
            refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 150
        onTriggered: root.refreshActive()
    }

    // Players don't announce position changes while playing, so ask for it every second
    Timer {
        interval: 1000
        repeat: true
        running: root.player?.isPlaying ?? false
        onTriggered: root.player.positionChanged()
    }
}

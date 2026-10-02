pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// What each app audio stream is playing, for the audio panel. Firefox names a tab's stream
// after the tab's title but later renames it to a generic "AudioStream", so the last real
// title seen for each stream is kept (for this session) and used instead. Created at start
// (see shell.qml) so it sees titles while the panel is closed.
Singleton {
    id: root

    // Stream names that say nothing about what's playing
    readonly property var genericNames: ["AudioStream", "Playback", "audio stream"]

    // Stream id -> last real title
    property var titles: ({})

    // [[id, name, app]] for the current app streams; changes whenever one is renamed
    readonly property var current: Pipewire.nodes.values
        .filter(node => node.type === PwNodeType.AudioOutStream)
        .map(node => [node.id, node.properties["media.name"] ?? "", node.properties["application.name"] ?? node.name])

    onCurrentChanged: {
        const titles = {};
        for (const [id, name, app] of current) {
            if (name !== "" && name !== app && !genericNames.includes(name))
                titles[id] = name;
            else if (root.titles[id])
                titles[id] = root.titles[id];
        }
        root.titles = titles;
    }

    // The title for a stream, or "" if it never had one
    function title(stream: PwNode): string {
        return titles[stream.id] ?? "";
    }
}

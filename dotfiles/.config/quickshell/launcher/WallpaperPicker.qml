import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Opened from the system panel's Wallpaper button: thumbnails of ~/Pictures/wallpapers, with
// the current one marked. Type to filter by name; arrows or Tab/Shift+Tab move, Enter or a
// click sets it (swaybg, as the old rofi menu did), Esc closes.
Item {
    id: root

    signal closeRequested

    readonly property string folder: Quickshell.env("HOME") + "/Pictures/wallpapers"
    // [{ name, path, size }], by name
    property var wallpapers: []
    // Size of the current wallpaper (a copy in ~/.cache), to tell which file it came from
    property real currentSize: -1
    property int selected: 0

    readonly property int columns: 3
    readonly property int cellHeight: 150

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var results: query === "" ? wallpapers : wallpapers.filter(w => w.name.toLowerCase().includes(query))

    onResultsChanged: selected = 0
    onSelectedChanged: grid.positionViewAtIndex(selected, GridView.Contain)

    function move(delta: int): void {
        if (results.length > 0)
            selected = Math.max(0, Math.min(results.length - 1, selected + delta));
    }

    // Start the new swaybg before stopping the old one, so there's no flash of no wallpaper
    function apply(wallpaper): void {
        if (!wallpaper)
            return;
        closeRequested();
        const current = "$HOME/.cache/current-wallpaper";
        Exec.run(`old=$(pgrep -x swaybg); cp ${Exec.quote(wallpaper.path)} "${current}" && setsid -f swaybg -i "${current}" -m fill && if [ -n "$old" ]; then sleep 0.5; kill $old; fi`);
    }

    implicitWidth: 612
    implicitHeight: body.implicitHeight

    // After the panel host has taken focus for itself, so typing goes to the search
    Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())

    // First line: the current wallpaper's size; then "size<TAB>path" per image
    Process {
        running: true
        command: ["sh", "-c", `stat -c %s "$HOME/.cache/current-wallpaper" 2>/dev/null || echo -1; find ${Exec.quote(root.folder)} -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf '%s\\t%p\\n'`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.currentSize = Number(lines.shift());
                root.wallpapers = lines
                    .filter(line => line.includes("\t"))
                    .map(line => {
                        const [size, path] = line.split("\t");
                        return { name: path.split("/").pop(), path: path, size: Number(size) };
                    })
                    .sort((a, b) => a.name.localeCompare(b.name));
                const current = root.wallpapers.findIndex(w => w.size === root.currentSize);
                if (current >= 0)
                    root.selected = current;
            }
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: 10

        // Search
        Rectangle {
            width: parent.width
            height: 44
            radius: 12
            color: Theme.surface

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                text: "\u{F002}"
                dim: true
            }

            TextInput {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                x: 44
                width: parent.width - 60
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search wallpapers…"
                    dim: true
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.closeRequested();
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.apply(root.results[root.selected]);
                        break;
                    case Qt.Key_Up:
                        root.move(-root.columns);
                        break;
                    case Qt.Key_Down:
                        root.move(root.columns);
                        break;
                    case Qt.Key_Left:
                        // Left/Right edit the search text unless it's empty
                        if (search.text !== "")
                            return;
                        root.move(-1);
                        break;
                    case Qt.Key_Right:
                        if (search.text !== "")
                            return;
                        root.move(1);
                        break;
                    case Qt.Key_Tab:
                        root.move(1);
                        break;
                    case Qt.Key_Backtab:
                        root.move(-1);
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }
        }

        GridView {
            id: grid
            width: parent.width
            // Up to three rows, shrinking for fewer wallpapers
            height: Math.max(1, Math.min(3, Math.ceil(root.results.length / root.columns))) * root.cellHeight
            cellWidth: width / root.columns
            cellHeight: root.cellHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.results

            PanelText {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: root.wallpapers.length === 0 ? `No images in ${root.folder}` : "No matching wallpapers"
                dim: true
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool isSelected: index === root.selected
                readonly property bool isCurrent: modelData.size === root.currentSize

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 12
                    color: cell.isSelected || mouse.containsMouse ? Theme.surfaceHover : "transparent"

                    Rectangle {
                        id: frame
                        x: 6
                        y: 6
                        width: parent.width - 12
                        height: width * 9 / 16
                        radius: 8
                        color: Theme.surface
                        border.width: cell.isSelected ? 2 : 0
                        border.color: Theme.accent
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: frame.border.width
                            source: "file://" + cell.modelData.path
                            // Decode small, so big wallpapers don't load at full size
                            sourceSize.width: 400
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    PanelText {
                        anchors.top: frame.bottom
                        anchors.topMargin: 6
                        x: 8
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        // Check mark on the current one
                        text: (cell.isCurrent ? "\u{F012C} " : "") + cell.modelData.name.replace(/\.[^.]+$/, "")
                        color: cell.isSelected || cell.isCurrent ? Theme.accent : Theme.text
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.apply(cell.modelData)
                }
            }
        }
    }
}

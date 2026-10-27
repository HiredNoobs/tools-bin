import QtQuick
import qs

// Horizontal slider from `from` to `to`. It doesn't change `value` itself: it emits `moved`
// while dragging, clicking or scrolling, and the owner applies it. With `moveOnRelease`, a
// drag emits it once, where it's let go (seeking, which players don't take many of at once).
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real scrollStep: 0.02
    property bool enabled: true
    property bool moveOnRelease: false

    signal moved(real value)

    readonly property bool dragging: mouse.pressed
    property real dragValue: 0
    // While dragging, follow the pointer rather than waiting for `value` to catch up
    readonly property real shownValue: dragging ? dragValue : value
    readonly property real fraction: to > from ? Math.max(0, Math.min(1, (shownValue - from) / (to - from))) : 0

    function valueAt(x: real): real {
        return from + (to - from) * Math.max(0, Math.min(1, x / width));
    }

    implicitWidth: 200
    implicitHeight: 20
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface

        Rectangle {
            width: parent.width * root.fraction
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.fraction * (root.width - width)
        width: 14
        height: 14
        radius: 7
        color: mouse.containsMouse || root.dragging ? Theme.accent : Theme.text

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        onPressed: event => {
            root.dragValue = root.valueAt(event.x);
            if (!root.moveOnRelease)
                root.moved(root.dragValue);
        }
        onPositionChanged: event => {
            if (!pressed)
                return;
            root.dragValue = root.valueAt(event.x);
            if (!root.moveOnRelease)
                root.moved(root.dragValue);
        }
        onReleased: {
            if (root.moveOnRelease)
                root.moved(root.dragValue);
        }
        onWheel: event => {
            const step = event.angleDelta.y > 0 ? root.scrollStep : -root.scrollStep;
            root.moved(Math.max(root.from, Math.min(root.to, root.value + step)));
        }
    }
}

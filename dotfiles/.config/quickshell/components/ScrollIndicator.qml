import QtQuick
import qs

// The thin bar on the right of something that scrolls (a Flickable, ListView or GridView),
// showing where in it you are; only while there's more than fits. Put it anywhere: it sits on
// `flickable` itself, so it doesn't scroll away with the content.
Rectangle {
    property Flickable flickable
    property real thickness: 3
    property real margin: 2

    parent: flickable
    visible: flickable !== null && flickable.contentHeight > flickable.height + 1
    anchors.right: parent?.right
    anchors.rightMargin: margin
    y: flickable ? flickable.visibleArea.yPosition * flickable.height : 0
    width: thickness
    height: flickable ? flickable.visibleArea.heightRatio * flickable.height : 0
    radius: thickness / 2
    color: Theme.subtext
    opacity: 0.6
}

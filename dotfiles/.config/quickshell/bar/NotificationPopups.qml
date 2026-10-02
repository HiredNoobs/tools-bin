import QtQuick
import qs
import qs.components
import qs.services

// Notification popups under the right end of the bar, attached like the panels.
// New ones slide in at the top; Notifications decides when each one goes.
Item {
    id: root

    // Set by the bar: the focused monitor's bar, with no panel open
    property bool shown: true

    readonly property bool attached: Theme.popupsAttached
    readonly property real fillet: attached ? Theme.radius : 0
    // Stays clear of the bar's rounded end so the fillet has a straight edge to join
    readonly property real edgeInset: attached ? Theme.radius : 0
    readonly property bool open: shown && Notifications.popups.length > 0
    readonly property int padding: 10
    // Notification id -> notification for the cards on screen, kept until the stack has
    // closed so the last cards don't blank out while it shrinks
    property var held: ({})

    // Keeps a ListModel in step with Notifications.popups, so only the popups that come and go
    // animate (replacing a plain array model would rebuild every card)
    function sync(): void {
        const ids = Notifications.popups.map(n => n.id);
        // The last popup going: keep the cards while the stack closes around them (like the
        // panels do), instead of shrinking an empty box
        if (ids.length === 0) {
            clearAfterClose.restart();
            return;
        }
        clearAfterClose.stop();
        for (let i = popupModel.count - 1; i >= 0; i--) {
            if (!ids.includes(popupModel.get(i).nid))
                popupModel.remove(i);
        }
        ids.forEach((id, index) => {
            let found = -1;
            for (let i = 0; i < popupModel.count; i++) {
                if (popupModel.get(i).nid === id)
                    found = i;
            }
            if (found === -1) {
                held = Object.assign({}, held, { [id]: Notifications.popups[index] });
                popupModel.insert(index, { nid: id });
            }
        });
    }

    x: parent.width - width - edgeInset
    y: Theme.barHeight + (attached ? 0 : Theme.panelGap)
    width: 400 + 2 * fillet
    height: open ? list.contentHeight + 2 * padding : 0
    opacity: open ? 1 : 0

    Behavior on height {
        NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.panelAnimDuration }
    }

    Component.onCompleted: sync()

    Connections {
        target: Notifications
        function onPopupsChanged() {
            root.sync();
        }
    }

    ListModel {
        id: popupModel
    }

    Timer {
        id: clearAfterClose
        interval: Theme.panelAnimDuration
        onTriggered: {
            popupModel.clear();
            root.held = {};
        }
    }

    PanelBackground {
        anchors.fill: parent
        attached: root.attached
    }

    Item {
        x: root.fillet
        width: parent.width - 2 * root.fillet
        height: parent.height
        clip: true

        ListView {
            id: list

            x: root.padding
            y: root.padding
            width: parent.width - 2 * root.padding
            height: contentHeight
            interactive: false
            spacing: 8
            model: popupModel

            delegate: NotificationCard {
                required property int nid

                width: list.width
                notification: root.held[nid] ?? null
                maxBodyLines: 4
                onHoveredChanged: {
                    if (hovered)
                        Notifications.hovered = notification;
                    else if (Notifications.hovered === notification)
                        Notifications.hovered = null;
                }
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                    NumberAnimation { property: "x"; from: 40; to: 0; duration: 250; easing.type: Easing.OutCubic }
                }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 150 }
            }
            // Also finishes any slide-in that a newer popup interrupted, which would otherwise
            // leave that card half faded
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; to: 1; duration: 200 }
                NumberAnimation { property: "x"; to: 0; duration: 200 }
            }
        }
    }
}

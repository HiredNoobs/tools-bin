pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// Notification daemon (replaces dunst). Notifications stay in the center until dismissed
// (this session only); new ones also show as popups unless Do Not Disturb is on.
Singleton {
    id: root

    property bool dnd: false
    // Received since the center was last opened
    property int unread: 0

    readonly property int maxPopups: ShellSettings.maxPopups
    readonly property int defaultTimeout: ShellSettings.popupSeconds * 1000

    // Shown as popups, newest first; extra ones wait in the queue
    property var popups: []
    property var queue: []
    // Notification id -> when its popup goes away (ms since epoch; 0 = stays, e.g. critical)
    property var deadlines: ({})
    // Popup under the mouse, which doesn't time out while hovered
    property var hovered: null
    // Notification id -> when it arrived, for "time ago"
    property var received: ({})

    // Newest first
    readonly property var list: [...server.trackedNotifications.values].reverse()

    // [{ app, icon, notifications }] in order of each app's newest notification
    readonly property var groups: {
        const byApp = new Map();
        for (const notification of list) {
            const app = notification.appName || "Other";
            if (!byApp.has(app))
                byApp.set(app, { app: app, icon: notification.appIcon, desktopEntry: notification.desktopEntry, notifications: [] });
            byApp.get(app).notifications.push(notification);
        }
        return [...byApp.values()];
    }

    function markRead(): void {
        unread = 0;
    }

    function dismiss(notification: var): void {
        notification.dismiss();
    }

    function dismissGroup(app: string): void {
        for (const notification of list.filter(n => (n.appName || "Other") === app))
            notification.dismiss();
    }

    function clearAll(): void {
        for (const notification of list)
            notification.dismiss();
    }

    // Runs an action; the notification goes away unless the app asked for it to stay (resident)
    function invoke(notification: var, action: var): void {
        action.invoke();
        if (!notification.resident)
            notification.dismiss();
    }

    function showPopup(notification: var): void {
        if (popups.includes(notification) || queue.includes(notification))
            return;
        if (popups.length < maxPopups) {
            const timeout = notification.urgency === NotificationUrgency.Critical ? 0 : notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : defaultTimeout;
            deadlines = Object.assign({}, deadlines, { [notification.id]: timeout > 0 ? Date.now() + timeout : 0 });
            popups = [notification, ...popups];
        } else {
            queue = [...queue, notification];
        }
    }

    // Hides a popup (the notification stays in the center) and lets a queued one in
    function hidePopup(notification: var): void {
        popups = popups.filter(n => n !== notification);
        queue = queue.filter(n => n !== notification);
        if (hovered === notification)
            hovered = null;
        while (popups.length < maxPopups && queue.length > 0) {
            const next = queue[0];
            queue = queue.slice(1);
            if (list.includes(next))
                showPopup(next);
        }
    }

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
            root.received = Object.assign({}, root.received, { [notification.id]: Date.now() });
            root.unread++;
            const id = notification.id;
            notification.closed.connect(() => {
                root.hidePopup(notification);
                const received = Object.assign({}, root.received);
                delete received[id];
                root.received = received;
            });
            if (!root.dnd || notification.urgency === NotificationUrgency.Critical)
                root.showPopup(notification);
        }
    }

    // Expires popups; a hovered one is held until the mouse leaves
    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            const now = Date.now();
            for (const notification of root.popups) {
                const deadline = root.deadlines[notification.id];
                if (!deadline)
                    continue;
                if (notification === root.hovered)
                    root.deadlines[notification.id] = Math.max(deadline, now + 1500);
                else if (now > deadline)
                    root.hidePopup(notification);
            }
        }
    }
}

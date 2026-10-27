pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// Notification daemon (replaces dunst). Notifications stay in the center until dismissed
// (this session only); new ones also show as popups unless Do Not Disturb is on. Transient
// ones (the app's hint) only pop up, and go once their popup does. Popups wait while no bar
// can show them (a panel open, the bar hidden, a fullscreen window), see NotificationPopups.
Singleton {
    id: root

    property bool dnd: false
    // When the center was last seen; it counts as seen all the time it's open
    property real lastSeen: 0
    // Received since then
    readonly property int unread: list.filter(n => (received[n.id] ?? 0) > lastSeen).length
    // When a bar last showed the popups (NotificationPopups keeps it up to date while it does)
    property real popupsSeenAt: 0

    readonly property int maxPopups: ShellSettings.maxPopups
    readonly property int defaultTimeout: ShellSettings.popupSeconds * 1000

    // Shown as popups, newest first; extra ones wait in the queue
    property var popups: []
    property var queue: []
    // Notification id -> when its popup goes away (ms since epoch; 0 = stays, e.g. critical)
    property var deadlines: ({})
    // Popup under the mouse, which doesn't time out while hovered
    property var hovered: null
    // Notification id -> when it arrived, for "time ago" (none for those from before the
    // shell last reloaded)
    property var received: ({})

    // Newest first, without transient ones
    readonly property var list: [...server.trackedNotifications.values].filter(n => !n.transient).reverse()

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
        lastSeen = Date.now();
    }

    function dismiss(notification: var): void {
        notification?.dismiss();
    }

    function dismissGroup(app: string): void {
        for (const notification of list.filter(n => (n.appName || "Other") === app))
            notification.dismiss();
    }

    function clearAll(): void {
        for (const notification of list)
            notification.dismiss();
    }

    // Runs an action; the notification goes away unless the app asked for it to stay (resident),
    // which invoke() itself sees to
    function invoke(notification: var, action: var): void {
        action.invoke();
    }

    function showPopup(notification: var): void {
        if (popups.includes(notification) || queue.includes(notification))
            return;
        if (popups.length < maxPopups) {
            // The app's own timeout is in ms: 0 is never, -1 (none given) the default
            const timeout = notification.urgency === NotificationUrgency.Critical || notification.expireTimeout === 0 ? 0 : notification.expireTimeout > 0 ? notification.expireTimeout : defaultTimeout;
            deadlines = Object.assign({}, deadlines, { [notification.id]: timeout > 0 ? Date.now() + timeout : 0 });
            popups = [notification, ...popups];
        } else {
            queue = [...queue, notification];
        }
    }

    // Hides a popup (the notification stays in the center, unless it's transient: then it goes,
    // unless it's going already, `closed`) and lets a queued one in
    function hidePopup(notification: var, closed: bool): void {
        popups = popups.filter(n => n !== notification);
        queue = queue.filter(n => n !== notification);
        if (hovered === notification)
            hovered = null;
        const left = Object.assign({}, deadlines);
        delete left[notification.id];
        deadlines = left;
        if (notification.transient && !closed)
            notification.expire();
        while (popups.length < maxPopups && queue.length > 0) {
            const next = queue[0];
            queue = queue.slice(1);
            if (server.trackedNotifications.values.includes(next))
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
            const id = notification.id;
            const popup = !root.dnd || notification.urgency === NotificationUrgency.Critical;
            // Transient and not shown: nothing to keep
            if (notification.transient && !popup && !notification.lastGeneration)
                return;
            notification.tracked = true;
            notification.closed.connect(() => {
                root.hidePopup(notification, true);
                const received = Object.assign({}, root.received);
                delete received[id];
                root.received = received;
            });
            // Kept from before the shell reloaded: already seen, so back in the center only (a
            // transient one's popup went with the old shell)
            if (notification.lastGeneration) {
                if (notification.transient)
                    notification.expire();
                return;
            }
            root.received = Object.assign({}, root.received, { [id]: Date.now() });
            if (popup)
                root.showPopup(notification);
        }
    }

    // Expires popups; a hovered one is held until the mouse leaves, and while no bar shows
    // them their time stands still
    Timer {
        property real last: 0

        interval: 250
        repeat: true
        running: root.popups.length > 0
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            const elapsed = now - last;
            last = now;
            const unseen = now - root.popupsSeenAt > 600;
            for (const notification of root.popups) {
                const deadline = root.deadlines[notification.id];
                if (!deadline)
                    continue;
                if (unseen)
                    root.deadlines[notification.id] = deadline + elapsed;
                else if (notification === root.hovered)
                    root.deadlines[notification.id] = Math.max(deadline, now + 1500);
                else if (now > deadline)
                    root.hidePopup(notification, false);
            }
        }
    }
}

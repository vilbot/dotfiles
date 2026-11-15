// The notification server: what's in the history (newest first) and what is up as a popup.
// Popups leave after their timeout but stay in the history, unless the app marks them transient.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root
    readonly property int historyLimit: 50
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: history.length
    property var times: ({})          // notification id -> "HH:mm" it arrived
    readonly property ListModel popups: ListModel {}   // { nid }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            root.times[n.id] = Qt.formatTime(new Date(), "HH:mm")
            n.closed.connect(() => root.removePopup(n.id))
            root.popups.append({ nid: n.id })
            const all = server.trackedNotifications.values
            for (let i = 0; i < all.length - root.historyLimit; i++) all[i].dismiss()
        }
    }

    function find(nid) { return server.trackedNotifications.values.find(n => n.id === nid) ?? null }
    function removePopup(nid) {
        for (let i = 0; i < popups.count; i++)
            if (popups.get(i).nid === nid) { popups.remove(i); return }
    }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
        Panels.historyOpen = false
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { Panels.historyOpen = !Panels.historyOpen }
        function open(): void { Panels.historyOpen = true }
        function close(): void { Panels.historyOpen = false }
        function clear(): void { root.clearAll() }
    }
}

// Notifications: the list (newest first, kept until opened or cleared) and the popups (leave
// after a few seconds but stay in the list). Do not disturb: no popups, the list still fills.
// Opening one (a click on its popup or its row) goes to the app that sent it and removes it.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root
    property bool listOpen: false
    property bool dnd: false
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property ListModel popups: ListModel {}   // { nid }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true
            n.closed.connect(() => root.unpop(n.id))
            if (!root.dnd) root.popups.insert(0, { nid: n.id })   // newest on top
        }
    }

    function find(nid) { return server.trackedNotifications.values.find(n => n.id === nid) ?? null }
    function unpop(nid) {
        for (let i = 0; i < popups.count; i++)
            if (popups.get(i).nid === nid) { popups.remove(i); return }
    }

    // The app's own "open" action brings the right window forward (Chrome: the tab; foot: the
    // terminal that rang, focus_on_activate in tty/hyprland.lua). Without one: its app's window.
    function open(n) {
        const act = n.actions.find(a => a.identifier === "default")
        if (act) { act.invoke(); n.dismiss(); listOpen = false; return }
        const names = [n.desktopEntry, n.appName].filter(s => s).map(s => s.toLowerCase())
        const win = Hyprland.toplevels.values.find(t => {
            const cls = (t.lastIpcObject?.class || t.wayland?.appId || "").toLowerCase()
            return cls && names.some(s => cls === s || cls.includes(s) || s.includes(cls))
        })
        if (win) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${win.address}" })`)
        n.dismiss()
        listOpen = false
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.listOpen = !root.listOpen }
        function clear(): void { root.clear() }
    }
    function clear() { for (const n of server.trackedNotifications.values.slice()) n.dismiss() }
}

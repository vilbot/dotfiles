// Windows on the desktops, most recently used first, grouped by app for the switcher.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property var mru: []                  // window addresses (no 0x), most recent first

    // only windows on a desktop: apps like Steam keep hidden helper windows around
    readonly property var all: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id > 0)

    function app(t) { return t.lastIpcObject?.class || t.wayland?.appId || t.title }
    function appIcon(cls) { return DesktopEntries.heuristicLookup(cls)?.icon ?? cls }
    function focus(t) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${t.address}" })`) }

    function byRecent() {
        const rank = t => { const i = mru.indexOf(t.address); return i < 0 ? 1e6 : i }
        return all.slice().sort((a, b) => rank(a) - rank(b))
    }
    // [{ cls, icon, windows }], apps and their windows most recently used first
    function byApp() {
        const byCls = {}, out = []
        for (const t of byRecent()) {
            const cls = app(t)
            if (!byCls[cls]) {
                byCls[cls] = { cls: cls, icon: appIcon(cls), windows: [] }
                out.push(byCls[cls])
            }
            byCls[cls].windows.push(t)
        }
        return out
    }

    function touch(addr) { mru = [addr].concat(mru.filter(a => a !== addr)) }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindowv2" && event.data) root.touch(event.data)
            else if (event.name === "closewindow") root.mru = root.mru.filter(a => a !== event.data)
        }
    }
    Process {      // the order before the shell started: Hyprland's focus history
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.mru = JSON.parse(text).sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                                                  .map(c => c.address.replace(/^0x/, ""))
        }
    }
}

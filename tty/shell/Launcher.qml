// The launcher (Cmd+Space): typed into the middle of the bar, results drop down below it.
// Empty: the favorites (tty/favorites.txt). Typing: every app, plus None's own entries (Settings,
// Files). Enter starts the pick, or runs what you typed as a command when nothing matches.
// Ctrl+F adds or removes a favorite.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    property string query: ""
    property int current: 0

    readonly property string tty: Quickshell.shellDir + "/.."
    function sh(cmd) { return () => Quickshell.execDetached(["sh", "-c", cmd]) }
    // apps go through gtk-launch: terminal apps then open in None's terminal (tty/bin)
    function app(id) { return sh("gtk-launch " + id) }

    // None's own entries, found like apps
    readonly property var own: [
        { id: "tty:settings", name: "Settings", detail: "sound, bluetooth, network (F5)", run: sh(tty + "/panel.sh") },
        { id: "tty:files", name: "Files", detail: "yazi", run: app("yazi") },
    ]
    readonly property var entries: own.concat(DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({ id: e.id, name: e.name, detail: e.genericName || "", words: (e.keywords ?? []).join(" "), run: app(e.id) })))

    // ---- favorites -----------------------------------------------------------------------
    FileView {
        id: favFile
        path: root.tty + "/favorites.txt"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var favorites: favFile.text().split("\n").filter(l => l !== "")
    function toggleFavorite(e) {
        if (!e) return
        const favs = favorites.includes(e.id) ? favorites.filter(f => f !== e.id) : favorites.concat([e.id])
        favFile.setText(favs.join("\n") + "\n")
    }

    // ---- search --------------------------------------------------------------------------
    // the name starting with it > a word in the name starting with it > anywhere in the name >
    // its letters in order > the extra words (keywords, generic name)
    function score(e, q) {
        const name = e.name.toLowerCase()
        if (name.startsWith(q)) return 100
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80
        if (name.includes(q)) return 60
        let i = 0
        for (const ch of name) if (ch === q[i]) i++
        if (i === q.length) return 30
        if ((e.detail + " " + (e.words ?? "")).toLowerCase().includes(q)) return 20
        return 0
    }
    readonly property var results: {
        const q = query.trim().toLowerCase()
        if (q === "")
            return favorites.map(id => entries.find(e => e.id === id)).filter(e => e)
        return entries
            .map(e => ({ e: e, s: score(e, q) + (favorites.includes(e.id) ? 5 : 0) }))
            .filter(x => x.s > 5)
            .sort((a, b) => b.s - a.s || a.e.name.length - b.e.name.length || a.e.name.localeCompare(b.e.name))
            .slice(0, 12)
            .map(x => x.e)
    }
    onResultsChanged: current = 0

    function move(by) { if (results.length) current = (current + by + results.length) % results.length }
    function toggle() { if (open) close(); else { query = ""; current = 0; open = true } }
    function close() { open = false }
    function run(i) {
        const e = results[i]
        if (e) e.run()
        else if (query.trim() !== "") Quickshell.execDetached(["sh", "-c", query])
        close()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function search(text: string): void { root.open = true; root.query = text }
    }
}

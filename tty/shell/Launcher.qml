// The launcher (Cmd+Space): typed into the middle of the bar, results drop down below it.
//   empty           the favorites (tty/favorites.txt; Ctrl+F adds or removes one)
//   a name          apps, None's own entries (Settings, Files, Terminal) and commands (Lock, Sleep,
//                   Log out, Reboot, Shut down; the last two ask for a second Enter)
//   Files <path>    the folder's contents: Enter opens a folder in yazi, a file in its app
//   nvim <path>     the same, Enter opens it in nvim (its terminal closes with it)
//   Terminal <path> the same, Enter opens a terminal there
// Tab completes: the picked file or folder (and goes into a folder), or the picked entry's name
// (`Files ~/` for the three above). Enter starts the pick, or runs what you typed as a command.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    property string query: ""
    property int current: 0
    property string confirming: ""        // the id of a command waiting for its second Enter

    readonly property string tty: Quickshell.shellDir + "/.."
    readonly property string home: Quickshell.env("HOME")
    readonly property string term: tty + "/term"   // None's terminal (Opt+Enter)
    function exec(args) { return () => Quickshell.execDetached(args) }
    function sh(cmd) { return exec(["sh", "-c", cmd]) }
    // apps go through gtk-launch: terminal apps then open in None's terminal (tty/bin)
    function app(id) { return sh("gtk-launch " + id) }
    function ipc(target, fn) { return exec(["qs", "-p", Quickshell.shellDir, "ipc", "call", target, fn]) }

    // ---- what can be found ---------------------------------------------------------------
    // pathCmd: the word that lists a folder with this entry (Tab on the entry writes it)
    readonly property var own: [
        { id: "tty:terminal", name: "Terminal", detail: "Opt+Enter", pathCmd: "Terminal", run: exec([term]) },
        { id: "tty:settings", name: "Settings", detail: "sound, bluetooth, network (F5)", run: sh(tty + "/panel.sh") },
        { id: "tty:files", name: "Files", detail: "yazi", pathCmd: "Files", run: exec([term, "yazi"]) },
        { id: "cmd:lock", name: "Lock", detail: "Ctrl+Cmd+Q", run: ipc("lock", "lock") },
        { id: "cmd:sleep", name: "Sleep", detail: "locks first", run: exec(["systemctl", "suspend"]) },
        { id: "cmd:logout", name: "Log out", detail: "Opt+Shift+Esc", run: ipc("lock", "logout") },
        { id: "cmd:reboot", name: "Reboot", detail: "", confirm: true, run: exec(["systemctl", "reboot"]) },
        { id: "cmd:shutdown", name: "Shut down", detail: "", confirm: true, run: exec(["systemctl", "poweroff"]) },
    ]
    readonly property var entries: own.concat(DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({ id: e.id, name: e.name, detail: e.genericName || "", words: (e.keywords ?? []).join(" "),
                     pathCmd: e.id === "nvim" ? "nvim" : undefined, run: app(e.id) })))

    // ---- favorites -----------------------------------------------------------------------
    FileView {
        id: favFile
        path: root.tty + "/favorites.txt"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var favorites: favFile.text().split("\n").filter(l => l !== "")
    function toggleFavorite(e) {
        if (!e || e.isPath) return
        const favs = favorites.includes(e.id) ? favorites.filter(f => f !== e.id) : favorites.concat([e.id])
        favFile.setText(favs.join("\n") + "\n")
    }

    // ---- paths: "Files ~/Doc" lists ~/ for names starting with "Doc" -------------------------
    readonly property var pathCmds: ({
        files: { open: (p, dir) => dir ? [term, "yazi", p] : ["xdg-open", p] },
        nvim: { open: (p, dir) => [term, "nvim", p] },
        terminal: { open: (p, dir) => ["sh", "-c", 'cd "$1" && exec "$2"', "_", dir ? p : p.replace(/\/[^/]*$/, "/"), term] },
    })
    readonly property var pathQuery: {
        const m = query.match(/^(files|nvim|terminal)\s+(.*)$/i)
        if (!m) return null
        const typed = m[2] === "" ? "~/" : m[2]
        const slash = typed.lastIndexOf("/")
        return { cmd: m[1].toLowerCase(), word: m[1], typed: typed,
                 folder: typed.slice(0, slash + 1), prefix: typed.slice(slash + 1) }
    }
    function expand(p) { return p.startsWith("~") ? home + p.slice(1) : p }
    // the folder's contents, read again when the folder changes
    property string listedFolder: ""
    property var listing: []              // ["name", "folder/"]
    readonly property string wantedFolder: pathQuery ? (pathQuery.folder || "./") : ""
    onWantedFolderChanged: if (wantedFolder !== "" && wantedFolder !== listedFolder) {
        listedFolder = wantedFolder
        lister.command = ["sh", "-c", 'cd -- "$1" 2>/dev/null && ls -1Ap', "_", expand(wantedFolder)]
        lister.running = true
    }
    Process {
        id: lister
        stdout: StdioCollector { onStreamFinished: root.listing = text.split("\n").filter(l => l !== "") }
    }
    function pathEntries(pq) {
        const pre = pq.prefix.toLowerCase()
        const hidden = pre.startsWith(".")
        const names = listing.filter(n => (hidden || !n.startsWith(".")) && n.toLowerCase().includes(pre))
        names.sort((a, b) => (b.endsWith("/") - a.endsWith("/"))
            || (b.toLowerCase().startsWith(pre) - a.toLowerCase().startsWith(pre)) || a.localeCompare(b))
        const how = pathCmds[pq.cmd]
        return names.map(n => {
            const shown = pq.folder + n, dir = n.endsWith("/")
            return { id: "path:" + shown, name: shown, detail: dir ? "folder" : "", isPath: true, isDir: dir,
                     run: exec(how.open(expand(shown), dir)) }
        })
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
        if (pathQuery) return pathEntries(pathQuery)
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
    onQueryChanged: confirming = ""

    function move(by) { if (results.length) current = (current + by + results.length) % results.length }
    function toggle() { if (open) close(); else { query = ""; current = 0; listedFolder = ""; open = true } }
    function close() { open = false; confirming = "" }
    function complete() {
        const e = results[current]
        if (!e) return
        if (pathQuery) query = pathQuery.word + " " + e.name   // a folder: its contents list next
        else query = e.pathCmd ? e.pathCmd + " ~/" : e.name
    }
    function run(i) {
        const e = results[i]
        if (e && e.confirm && confirming !== e.id) { confirming = e.id; return }   // once more to do it
        if (e) e.run()
        else if (pathQuery) exec(pathCmds[pathQuery.cmd].open(expand(pathQuery.typed), pathQuery.typed.endsWith("/")))()
        else if (query.trim() !== "") Quickshell.execDetached(["sh", "-c", query])
        close()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function search(text: string): void { root.open = true; root.query = text }
        function complete(): void { root.complete() }   // Tab, for testing
    }
}

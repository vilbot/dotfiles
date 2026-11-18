// The launcher (Cmd+Space): typed into the middle of the bar, results drop down below it.
//   empty           the favorites (tty/favorites.txt; Ctrl+F adds or removes one)
//   a name          apps, None's own entries (Settings, Files, Neovim, Terminal) and commands (Lock, Sleep,
//                   Log out, Reboot, Shut down; the last two ask for a second Enter)
//   Files <path>    the folder's contents: Enter opens a folder in yazi, a file in its app
//   nvim <path>     the same, Enter opens it in nvim (its terminal closes with it)
//   Terminal <path> the same, Enter opens a terminal there
//   Google Chrome <text>  (or `chrome <text>`) websites: nothing typed yet, a new window (picked), then
//                   the common ones (tty/sites.txt) and the ones you go to most; typing, what you typed (an
//                   address, or a search), Chrome's history and Google's suggestions, as Chrome's
//                   own address bar does. Enter opens it in Chrome,
//                   Cmd+N in a new window, Cmd+Shift+N in a new incognito one (also on Google Chrome itself)
// Tab completes: the picked file or folder (and goes into a folder), the picked site or
// suggestion, or the picked entry's name (`Files ~/` for the three above, `Google Chrome `).
// Enter starts the pick, or runs what you typed as a command.
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
    property bool desk: false             // an empty desktop shows it (EmptyDesk.qml); Cmd+Space does nothing then

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
        // nvim comes from bob (a version manager), which installs no app entry of its own
        { id: "tty:nvim", name: "Neovim", detail: "nvim", words: "vim editor", pathCmd: "nvim", run: exec([term, "nvim"]) },
        { id: "cmd:lock", name: "Lock", detail: "Ctrl+Cmd+Q", run: ipc("lock", "lock") },
        { id: "cmd:sleep", name: "Sleep", detail: "locks first", run: exec(["systemctl", "suspend"]) },
        { id: "cmd:logout", name: "Log out", detail: "Opt+Shift+Esc", run: ipc("lock", "logout") },
        { id: "cmd:reboot", name: "Reboot", detail: "", confirm: true, run: exec(["systemctl", "reboot"]) },
        { id: "cmd:shutdown", name: "Shut down", detail: "", confirm: true, run: exec(["systemctl", "poweroff"]) },
    ]
    readonly property var entries: own.concat(DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({ id: e.id, name: e.name, detail: e.genericName || "", words: (e.keywords ?? []).join(" "),
                     webCmd: e.id === "google-chrome" ? e.name : undefined,
                     run: e.id === "google-chrome" ? chromeApp(app(e.id)) : app(e.id) })))

    // ---- favorites -----------------------------------------------------------------------
    FileView {
        id: favFile
        path: root.tty + "/favorites.txt"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var favorites: favFile.text().split("\n").filter(l => l !== "")
    function toggleFavorite(e) {
        if (!e || e.isPath || e.isWeb) return
        const favs = favorites.includes(e.id) ? favorites.filter(f => f !== e.id) : favorites.concat([e.id])
        favFile.setText(favs.join("\n") + "\n")
    }

    // ---- paths: "Files ~/Doc" lists ~/ for names starting with "Doc" -------------------------
    readonly property var pathCmds: ({
        files: { open: (p, dir) => dir ? [term, "yazi", p] : ["xdg-open", p] },
        // nvim runs in the folder (a file's own folder), so its working directory is that
        nvim: { open: (p, dir) => ["sh", "-c", 'cd "$1" && exec "$2" nvim "$3"', "_", dir ? p : p.replace(/\/[^/]*$/, "/"), term, dir ? "." : p] },
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
        const rows = names.map(n => {
            const shown = pq.folder + n, dir = n.endsWith("/")
            return { id: "path:" + shown, name: shown, detail: dir ? "folder" : "", isPath: true, isDir: dir,
                     run: exec(how.open(expand(shown), dir)) }
        })
        // a path ending in "/" means that folder: it comes first (and is picked), so Enter opens
        // what the prompt says; what's inside follows
        if (pq.prefix === "")
            rows.unshift({ id: "path:" + pq.folder, name: pq.folder, detail: "this folder", isPath: true, isDir: true,
                           run: exec(how.open(expand(pq.folder), true)) })
        return rows
    }

    // ---- websites: "Google Chrome you" lists sites and searches for "you" ---------------------
    readonly property var webQuery: {
        const m = query.match(/^(google chrome|chrome)\s(.*)$/i)
        return m ? { word: m[1], text: m[2].trim() } : null
    }
    // how: "" (a tab in Chrome's window), "incognito" or "window" (a new one)
    function chromeFlags(how) { return how === "incognito" ? ["--incognito"] : how === "window" ? ["--new-window"] : [] }
    // A tab goes into Chrome's last window, but Chrome can't bring it forward itself (no
    // activation token), so focus that window: the most recently focused one that isn't incognito.
    readonly property string focusChrome: "a=$(hyprctl clients -j | jq -r '[.[] | select(.class == \"google-chrome\" "
        + "and (.title | endswith(\"(Incognito)\") | not))] | sort_by(.focusHistoryID) | .[0].address // empty'); "
        + "[ -n \"$a\" ] && hyprctl dispatch \"hl.dsp.focus({ window = \\\"address:$a\\\" })\" >/dev/null"
    function chrome(url) {
        return how => how ? Quickshell.execDetached(["google-chrome-stable"].concat(chromeFlags(how), [url]))
                          : Quickshell.execDetached(["sh", "-c", focusChrome + "; exec google-chrome-stable \"$1\"", "sh", url])
    }
    // Google Chrome itself: Enter as any app, Cmd+N / Cmd+Shift+N a new (incognito) window
    function chromeApp(plain) {
        return how => how ? Quickshell.execDetached(["google-chrome-stable"].concat(chromeFlags(how))) : plain()
    }
    // can the pick open in a new Chrome window (Cmd+N)?
    function chromePick() { const e = results[current]; return !!e && (e.isWeb || e.id === "google-chrome") }
    // an address (has a dot or a scheme, no spaces) or words to search for
    function webTarget(text) {
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(text) || /^(localhost|[^\s\/]+\.[^\s\/]{2,})(:\d+)?(\/\S*)?$/i.test(text))
            return { url: /^[a-z][a-z0-9+.-]*:\/\//i.test(text) ? text : "https://" + text, search: false }
        return { url: "https://www.google.com/search?q=" + encodeURIComponent(text), search: true }
    }
    function host(url) { return url.replace(/^[a-z]+:\/\/(www\.)?/i, "").replace(/\/.*$/, "") }
    FileView {
        id: sitesFile
        path: root.tty + "/sites.txt"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var sites: sitesFile.text().split("\n").filter(l => l.trim() !== "")
        .map(l => { const i = l.lastIndexOf(" "); return { title: l.slice(0, i).trim(), url: l.slice(i + 1).trim() } })
    // Chrome's history (read-only: Chrome keeps it locked) and Google's suggestions, fetched a
    // moment after typing stops; an answer for text that has changed since is dropped
    property var history: []              // [{ title, url }]
    property var suggestions: []          // ["text"]
    property var fetchedFor: null         // the text the lists are for (null: none yet)
    readonly property string historyDb: home + "/.config/google-chrome/Default/History"
    onWebQueryChanged: if (webQuery && webQuery.text !== fetchedFor) fetchTimer.restart()
    Timer {
        id: fetchTimer
        interval: 120
        onTriggered: {
            if (!root.webQuery) return
            const t = root.webQuery.text
            root.fetchedFor = t
            const like = "%" + t.replace(/'/g, "''") + "%"
            const where = t === "" ? "" : ` and (url like '${like}' or title like '${like}')`
            historyProc.wanted = t
            historyProc.exec(["sqlite3", "-readonly", "-separator", "\t", `file:${root.historyDb}?immutable=1`,
                `select url, title from urls where hidden = 0${where} order by typed_count desc, visit_count desc limit ${t === "" ? 8 : 5}`])
            if (t === "") { root.suggestions = []; return }
            suggestProc.wanted = t
            suggestProc.exec(["curl", "-s", "--max-time", "2", "--get", "--data-urlencode", "q=" + t,
                "https://suggestqueries.google.com/complete/search?client=chrome"])
        }
    }
    Process {
        id: historyProc
        property string wanted
        stdout: StdioCollector {
            onStreamFinished: if (root.webQuery && root.webQuery.text === historyProc.wanted)
                root.history = text.split("\n").filter(l => l).map(l => { const [url, title] = l.split("\t"); return { url: url, title: title || "" } })
        }
    }
    Process {
        id: suggestProc
        property string wanted
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.webQuery || root.webQuery.text !== suggestProc.wanted) return
                try { root.suggestions = JSON.parse(text)[1].slice(0, 6) } catch (e) { root.suggestions = [] }
            }
        }
    }
    function webEntries(wq) {
        const rows = [], seen = new Set()
        const add = (name, detail, url, done) => {
            const key = url.replace(/^[a-z]+:\/\/(www\.)?/i, "").replace(/\/$/, "")   // one row per page
            if (seen.has(key)) return
            seen.add(key)
            rows.push({ id: "web:" + url, name: name, detail: detail, isWeb: true, complete: done, run: chrome(url) })
        }
        if (wq.text !== "") {
            const t = webTarget(wq.text)
            add(wq.text, t.search ? "Google search" : "open", t.url, wq.text)
        } else {
            add("New window", "empty", "chrome://newtab", "")   // first, so Enter on `Google Chrome ` opens nothing else
            // Enter and Cmd+N: a new window on a new tab; Cmd+Shift+N: incognito
            rows[0].run = how => Quickshell.execDetached(["google-chrome-stable"].concat(chromeFlags(how || "window")))
            for (const s of sites) add(s.title, host(s.url), s.url, host(s.url))
        }
        for (const h of history) add(h.title || host(h.url), host(h.url), h.url, h.url.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, ""))
        if (wq.text !== "")
            for (const s of suggestions) { const t = webTarget(s); add(s, t.search ? "search" : "open", t.url, s) }
        return rows.slice(0, 12)
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
        if (webQuery) return webEntries(webQuery)
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
    function toggle() { if (desk) return; if (open) close(); else { query = ""; current = 0; listedFolder = ""; open = true } }
    function close() { open = false; confirming = ""; query = ""; fetchedFor = null }
    // what Tab makes of the query: the picked path (a folder: its contents list next), or the
    // picked entry's name (`Files ~/` for the entries that list folders)
    function completion() {
        const e = results[current]
        if (!e) return query
        if (pathQuery) return pathQuery.word + " " + e.name
        if (webQuery) return webQuery.word + " " + e.complete
        return e.pathCmd ? e.pathCmd + " ~/" : e.webCmd ? e.webCmd + " " : e.name
    }
    function complete() { query = completion() }
    // the rest of it, shown dimmed after what you typed (when it continues what you typed)
    readonly property string ghost: {
        const c = completion()
        return query !== "" && c.length > query.length && c.toLowerCase().startsWith(query.toLowerCase())
            ? c.slice(query.length) : ""
    }
    // how: "" (Enter), "incognito" (Cmd+Shift+N) or "window" (Cmd+N): only Chrome's rows use it
    function run(i, how) {
        const e = results[i]
        if (e && e.confirm && confirming !== e.id) { confirming = e.id; return }   // once more to do it
        if (e) e.run(how || "")
        else if (pathQuery) exec(pathCmds[pathQuery.cmd].open(expand(pathQuery.typed), pathQuery.typed.endsWith("/")))()
        else if (query.trim() !== "") Quickshell.execDetached(["sh", "-c", query])
        close()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function search(text: string): void { if (!root.desk) root.open = true; root.query = text }
        function complete(): void { root.complete() }   // Tab, for testing
    }
}

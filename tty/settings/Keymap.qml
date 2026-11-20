// The keys of the desktop (tty/keys.toml), for the Shortcuts page: mackeys' model of them
// (~/.local/state/mackeys/keymap.json, written on every reload), saving through `mackeys set`
// (it keeps the file's comments and refuses keys that don't work), recording keys through
// mackeys' socket (so they don't do anything while you press them), and undo.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var model: ({})
    readonly property int desktops: model.desktops ?? 5
    readonly property string file: model.file ?? ""
    readonly property string mackeys: Quickshell.shellDir + "/../../keys/daemon/target/release/mackeys"

    // what was saved but isn't in keymap.json yet (mackeys reloads within a second)
    property var saving: ({})

    // every row, in the file's order: { group, action, label, keys, layer, app, fixed }
    readonly property var rows: {
        const out = []
        for (const g of model.groups ?? [])
            for (const r of g.rows)
                out.push(Object.assign({}, r, { group: g.title, keys: saving[r.action] ?? r.keys ?? [] }))
        return out
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/mackeys/keymap.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.model = JSON.parse(text()); root.saving = ({}) } catch (e) {}
        }
    }

    // ---- writing keys -------------------------------------------------------------------
    readonly property var order: ["ctrl", "opt", "shift", "cmd"]
    function split(k) {
        const parts = k.split("+")
        if (k.endsWith("++")) { parts.splice(-2, 2, "+") }
        return { mods: parts.slice(0, -1), key: parts[parts.length - 1] }
    }
    function base(m) { return m.length > 1 && (m[0] === "l" || m[0] === "r") && order.includes(m.slice(1)) ? m.slice(1) : m }
    // one way of writing keys (as mackeys does): modifiers in the Mac's order
    function canon(k) {
        const s = split(k)
        s.mods.sort((a, b) => order.indexOf(base(a)) - order.indexOf(base(b)))
        return s.mods.concat([s.key]).join("+")
    }
    // every key a row's keys stand for: {n} = 1..desktops, {dir} = h j k l, {arrow} = arrows
    function expand(keys) {
        const out = []
        for (const k of keys) {
            if (k.includes("{n}")) for (let n = 1; n <= desktops; n++) out.push(canon(k.replace("{n}", n)))
            else if (k.includes("{dir}")) for (const d of ["h", "j", "k", "l"]) out.push(canon(k.replace("{dir}", d)))
            else if (k.includes("{arrow}")) for (const d of ["left", "down", "up", "right"]) out.push(canon(k.replace("{arrow}", d)))
            else out.push(canon(k))
        }
        return out
    }
    readonly property var glyphs: ({ ctrl: "⌃", opt: "⌥", shift: "⇧", cmd: "⌘" })
    readonly property var names: ({
        space: "Space", enter: "↩", return: "↩", kpenter: "⌤", esc: "Esc", escape: "Esc", tab: "⇥",
        backspace: "⌫", delete: "⌦", left: "←", right: "→", up: "↑", down: "↓", pageup: "PgUp",
        pagedown: "PgDn", home: "Home", end: "End", grave: "`", slash: "/",
        "{dir}": "H J K L", "{arrow}": "← ↓ ↑ →",
    })
    // as macOS menus write keys: "opt+shift+{n}" -> "⌥ ⇧ 1–5", "opt+shift+/" -> "⌥ ?"
    function label(k) {
        const s = split(k)
        let mods = s.mods.map(base), key = s.key
        if (mods.includes("shift") && (key === "/" || key === "`")) { key = key === "/" ? "?" : "~"; mods = mods.filter(m => m !== "shift") }
        const name = key === "{n}" ? "1–" + desktops : names[key] ?? key.toUpperCase()
        return order.filter(m => mods.includes(m)).map(m => glyphs[m]).concat([name]).join(" ")
    }
    // what a search for keys looks like typed: "⌥1", "opt 1", "alt+shift+f" -> {mods, key}
    function asKeys(text) {
        let t = text.toLowerCase().trim()
        for (const [g, m] of [["⌃", "ctrl "], ["⌥", "opt "], ["⇧", "shift "], ["⌘", "cmd "]]) t = t.split(g).join(m)
        const words = t.split(/[\s+]+/).filter(w => w)
        const alias = { option: "opt", alt: "opt", command: "cmd", control: "ctrl", super: "ctrl", ctl: "ctrl" }
        const mods = [], rest = []
        for (const w of words) {
            const m = alias[w] ?? w
            if (order.includes(m)) mods.push(m); else rest.push(w)
        }
        if (!mods.length || rest.length > 1) return null
        return { mods: mods, key: rest[0] ?? "" }
    }
    // a row fits the search: every word in its label, action or section, or its keys fit typed keys
    function fits(row, text) {
        const q = text.trim().toLowerCase()
        if (!q) return true
        const keys = asKeys(q)
        if (keys) {
            return expand(row.keys).some(k => {
                const s = split(k), mods = s.mods.map(base)
                return keys.mods.every(m => mods.includes(m)) && (!keys.key || s.key === keys.key)
            })
        }
        const hay = (row.label + " " + (row.action ?? "") + " " + row.group + " " + row.keys.join(" ") + " "
                     + row.keys.map(label).join(" ")).toLowerCase()
        if (q.includes("+") && expand(row.keys).includes(canon(q))) return true
        return q.split(/\s+/).every(w => hay.includes(w))
    }

    // the other rows in the same layer that already have one of these keys
    function clashes(row, keys) {
        const mine = expand(keys)
        return rows.filter(r => r.action && r.action !== row.action && r.layer === row.layer
                                && expand(r.keys).some(k => mine.includes(k)))
    }

    // ---- saving, undo -------------------------------------------------------------------
    property var undoStack: []
    property var redoStack: []
    property string error: ""
    signal saved()

    // changes: { action: [keys] }; `before`: the keys they had (what undo puts back)
    function save(changes, history) {
        const before = {}
        for (const a in changes) before[a] = (rows.find(r => r.action === a) ?? { keys: [] }).keys
        proc.pushed = history !== false
        if (proc.pushed) { undoStack = undoStack.concat([{ before: before, after: changes }]); redoStack = [] }
        saving = Object.assign({}, saving, changes)
        error = ""
        proc.command = ["sh", "-c", 'out=$("$1" set "$2" "$3" 2>&1); printf "%s\\n%s" "$?" "$out"', "sh",
                        mackeys, file, JSON.stringify(changes)]
        proc.running = true
    }
    function undo() {
        const last = undoStack[undoStack.length - 1]
        if (!last) return false
        undoStack = undoStack.slice(0, -1)
        redoStack = redoStack.concat([last])
        save(last.before, false)
        return true
    }
    function redo() {
        const last = redoStack[redoStack.length - 1]
        if (!last) return false
        redoStack = redoStack.slice(0, -1)
        undoStack = undoStack.concat([last])
        save(last.after, false)
        return true
    }
    Process {
        id: proc
        property bool pushed: false   // this save added to the undo history
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                if (lines[0] === "0") { root.saved(); return }
                // mackeys refused: back to what the file has, and say why (its last line)
                root.saving = ({})
                if (proc.pushed) root.undoStack = root.undoStack.slice(0, -1)
                root.error = lines.slice(1).join("\n").trim().split("\n").pop().trim() || "couldn't save"
            }
        }
    }

    // ---- recording ----------------------------------------------------------------------
    // record(done): mackeys catches the next keys pressed (they do nothing else) and done gets
    // "opt+shift+1", or "" when Esc was pressed twice or it was cancelled.
    property bool recording: false
    property var done: null
    readonly property bool canRecord: sock.connected
    property int stale: 0      // "cancelled" answers still to come for recordings replaced since
    function record(callback) {
        if (recording) { stale++; finish("") }   // mackeys answers the old one "cancelled"
        done = callback
        recording = true
        sock.write("record\n")
        sock.flush()
    }
    function cancel() {
        if (!recording) return
        sock.write("cancel\n")
        sock.flush()
    }
    function finish(keys) {
        const d = done
        recording = false
        done = null
        if (d) d(keys)
    }
    Socket {
        id: sock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/mackeys.sock"
        connected: true
        onConnectedChanged: if (!connected) { root.stale = 0; root.finish(""); retry.start() }
        parser: SplitParser {
            onRead: line => {
                if (line.startsWith("keys ")) root.finish(line.slice(5))
                else if (line === "cancelled" && root.stale > 0) root.stale--
                else if (line === "cancelled") root.finish("")
            }
        }
    }
    Timer {   // mackeys restarted (a new keymap): connect again
        id: retry
        interval: 1000
        onTriggered: { sock.connected = false; sock.connected = true; if (!sock.connected) start() }
    }
}

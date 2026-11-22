// The keys of the desktop (tty/keys.json with yours laid over it), for the Shortcuts page: its
// rows, saving (what you changed, to ~/.config/none/keys.json, then `hyprctl reload`, which binds
// them again through tty/binds.lua), undo, and recording
// keys: Hyprland switches to an empty submap ("none-record", tty/binds.lua) meanwhile, so the keys
// pressed reach this window and do nothing else.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var model: AppKeys.model
    readonly property int desktops: AppKeys.desktops

    // every row, in the file's order: { group, action, label, keys, layer, app, fixed, keysLabel }
    readonly property var rows: {
        const out = []
        for (const s of model.sections ?? []) {
            for (const a in s.actions ?? {})
                out.push({ group: s.title, action: a, label: s.actions[a].label ?? a, keys: s.actions[a].keys ?? [], layer: "desktop", app: "" })
            for (const n of (model.notes ?? {})[s.title] ?? [])
                out.push({ group: s.title, label: n[0], keys: [], keysLabel: [n[1]], fixed: true, layer: "desktop" })
        }
        for (const app in model.apps ?? {}) {
            const g = model.apps[app]
            for (const a in g.actions ?? {})
                out.push({ group: g.title ?? app, action: a, label: g.actions[a].label ?? a, keys: g.actions[a].keys ?? [], layer: app, app: app })
        }
        return out
    }

    // ---- writing keys -------------------------------------------------------------------
    function split(k) { return AppKeys.parse(k) }
    function canon(k) { return AppKeys.canon(k) }
    function label(k) { return AppKeys.show(k) }
    // every key a row's keys stand for: {n} = 1..desktops, {dir} = H J K L, {arrow} = arrows
    function expand(keys) {
        const out = []
        for (const k of keys) {
            if (k.includes("{n}")) for (let n = 1; n <= desktops; n++) out.push(canon(k.replace("{n}", n)))
            else if (k.includes("{dir}")) for (const d of ["H", "J", "K", "L"]) out.push(canon(k.replace("{dir}", d)))
            else if (k.includes("{arrow}")) for (const d of ["Left", "Down", "Up", "Right"]) out.push(canon(k.replace("{arrow}", d)))
            else out.push(canon(k))
        }
        return out
    }
    // what a search for keys looks like typed: "super 1", "alt+shift+f", "ctrl" -> {mods, key}
    function asKeys(text) {
        const words = text.toLowerCase().trim().split(/[\s+]+/).filter(w => w)
        const alias = { super: "SUPER", cmd: "SUPER", win: "SUPER", meta: "SUPER", ctrl: "CTRL", control: "CTRL",
                        alt: "ALT", opt: "ALT", option: "ALT", shift: "SHIFT" }
        const mods = [], rest = []
        for (const w of words) { if (alias[w]) mods.push(alias[w]); else rest.push(w) }
        if (!mods.length || rest.length > 1) return null
        return { mods: mods, key: rest[0] ? split(rest[0]).key : "" }
    }
    // a row fits the search: every word in its label, action or section, or its keys fit typed keys
    function fits(row, text) {
        const q = text.trim().toLowerCase()
        if (!q) return true
        const keys = asKeys(q)
        if (keys) {
            return expand(row.keys).some(k => {
                const s = split(k)
                return keys.mods.every(m => s.mods.includes(m)) && (!keys.key || s.key === keys.key)
            })
        }
        const hay = (row.label + " " + (row.action ?? "") + " " + row.group + " " + row.keys.join(" ") + " "
                     + row.keys.map(label).join(" ") + " " + (row.keysLabel ?? []).join(" ")).toLowerCase()
        return q.split(/\s+/).every(w => hay.includes(w))
    }

    // the other rows that already have one of these keys: in the same app, or a desktop key
    // (Hyprland takes those before any app sees them)
    function clashes(row, keys) {
        const mine = expand(keys)
        return rows.filter(r => r.action && r.action !== row.action
                                && (r.layer === row.layer || r.layer === "desktop" || row.layer === "desktop")
                                && expand(r.keys).some(k => mine.includes(k)))
    }

    // ---- saving, undo -------------------------------------------------------------------
    property var undoStack: []
    property var redoStack: []
    property string error: ""
    signal saved()

    // your keys.json as it is written: one action per line
    function one(v) {
        if (Array.isArray(v)) return "[" + v.map(one).join(", ") + "]"
        return JSON.stringify(v)
    }
    function format(data) {
        const parts = Object.keys(data).filter(k => k !== "keys").map(k => "  " + JSON.stringify(k) + ": " + JSON.stringify(data[k]))
        const names = Object.keys(data.keys ?? {})
        parts.push('  "keys": {' + (names.length ? "\n" + names.map(a => "    " + JSON.stringify(a) + ": " + one(data.keys[a])).join(",\n") + "\n  " : "") + "}")
        return "{\n" + parts.join(",\n") + "\n}\n"
    }

    function keysOf(action) { return (rows.find(r => r.action === action) ?? { keys: [] }).keys }
    // an action's keys in None's own keys.json
    function defaultKeys(action) {
        const base = AppKeys.base
        for (const s of base.sections ?? []) if (s.actions && s.actions[action]) return s.actions[action].keys ?? []
        for (const app in base.apps ?? {}) { const a = base.apps[app].actions ?? {}; if (a[action]) return a[action].keys ?? [] }
        return []
    }
    function sameKeys(a, b) { return a.map(canon).join("|") === b.map(canon).join("|") }
    // changes: { action: [keys] }; `history` false for undo/redo themselves. Your file keeps
    // only the actions whose keys differ from None's own.
    function save(changes, history) {
        const before = {}
        for (const a in changes) {
            if (!rows.some(r => r.action === a)) { error = "no action " + a + " in tty/keys.json"; return }
            before[a] = keysOf(a)
        }
        const data = JSON.parse(JSON.stringify(AppKeys.mine))
        const keys = data.keys ?? {}
        for (const a in changes) {
            if (sameKeys(changes[a], defaultKeys(a))) delete keys[a]
            else keys[a] = changes[a]
        }
        data.keys = keys
        if (history !== false) { undoStack = undoStack.concat([{ before: before, after: changes }]); redoStack = [] }
        error = ""
        writer.setText(format(data))
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
    FileView {
        id: writer
        path: AppKeys.userPath
        blockLoading: true
        atomicWrites: true
        onSaved: reload.running = true
        onSaveFailed: err => root.error = "couldn't save " + AppKeys.userPath + ": " + err
    }
    // Hyprland binds the keys again (desktop keys); the apps read keys.json themselves
    Process {
        id: reload
        command: ["hyprctl", "reload"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "ok") root.saved()
                else root.error = text.trim().split("\n").pop() || "Hyprland didn't reload"
            }
        }
    }

    // ---- recording ----------------------------------------------------------------------
    // record(done): the next keys pressed in this window are done's "SUPER + SHIFT + 1"; "" when
    // Esc was pressed twice, it was cancelled, or nothing came for a while. Esc alone: Esc, then
    // nothing else for a moment.
    property bool recording: false
    property var done: null
    readonly property bool canRecord: true
    property bool escSeen: false
    function submap(name) {
        Quickshell.execDetached(["hyprctl", "eval", 'hl.dispatch(hl.dsp.submap("' + name + '"))'])
    }
    function record(callback) {
        if (recording) finish("")
        done = callback
        recording = true
        escSeen = false
        submap("none-record")
        giveUp.restart()
    }
    function cancel() { if (recording) finish("") }
    function finish(keys) {
        const d = done
        recording = false
        done = null
        escSeen = false
        escAlone.stop()
        giveUp.stop()
        submap("reset")
        if (d) d(keys)
    }
    // a key event while recording (the window sends every one here); modifiers alone wait
    function keyEvent(event) {
        if (event.isAutoRepeat) return
        const k = AppKeys.name(event)
        if (!k) return
        if (k === "Escape") {
            if (escSeen) { finish(""); return }
            escSeen = true
            escAlone.restart()
            return
        }
        finish(k)
    }
    Timer { id: escAlone; interval: 700; onTriggered: if (root.recording && root.escSeen) root.finish("Escape") }
    Timer { id: giveUp; interval: 20000; onTriggered: root.cancel() }
    Component.onDestruction: if (recording) submap("reset")
}

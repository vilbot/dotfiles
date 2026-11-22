pragma Singleton
// None's keys as tty/keys.json writes them ("SUPER + SHIFT + H"), for its own apps: the launcher's
// and the Settings app's keys ("apps" there) and the desktop keys' labels. Keys are matched by
// the key's Linux code (US names: on Swerty the key right of L is still "semicolon"), as Hyprland
// does with its first layout. tty/settings uses this file too (a link).
//   AppKeys.action("launcher", event)  the action those keys are ("launcher.next"), or ""
//   AppKeys.label("launcher.favorite") its first key ("Ctrl+F"), or ""
//   AppKeys.parse("CTRL + N") / write(mods, name) / show("SUPER + {n}") / name(event)
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string path: Quickshell.shellDir + "/../keys.json"
    // read when first asked (a key can come right after start); a file caught half-written
    // doesn't parse: the last good one stays
    readonly property var last: ({ good: {} })   // changing it notifies nothing: no binding loop
    readonly property var model: {
        try { last.good = JSON.parse(file.text()) } catch (e) {}
        return last.good
    }
    readonly property int desktops: model.desktops ?? 5

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // ---- key names ------------------------------------------------------------------------
    // Linux key codes by name (the US layout's keysyms, as Hyprland and xkb write them)
    readonly property var codes: {
        const c = { Escape: 1, BackSpace: 14, Tab: 15, Return: 28, space: 57, KP_Enter: 96,
            minus: 12, equal: 13, bracketleft: 26, bracketright: 27, semicolon: 39, apostrophe: 40,
            grave: 41, backslash: 43, comma: 51, period: 52, slash: 53,
            Home: 102, Up: 103, Prior: 104, Left: 105, Right: 106, End: 107, Down: 108, Next: 109,
            Insert: 110, Delete: 111, F11: 87, F12: 88 }
        "1234567890".split("").forEach((d, i) => c[d] = 2 + i)
        const rows = [["QWERTYUIOP", 16], ["ASDFGHJKL", 30], ["ZXCVBNM", 44]]
        for (const [letters, first] of rows) letters.split("").forEach((l, i) => c[l] = first + i)
        for (let n = 1; n <= 10; n++) c["F" + n] = 58 + n
        return c
    }
    readonly property var byCode: {
        const out = {}
        for (const k in codes) out[codes[k]] = k
        return out
    }
    readonly property var order: ["SUPER", "CTRL", "ALT", "SHIFT"]

    // "ctrl + shift + n" -> { mods: ["CTRL", "SHIFT"], key: "N" } (key as keys.json names it)
    function parse(keys) {
        const parts = keys.split("+").map(p => p.trim()).filter(p => p)
        const mods = parts.slice(0, -1).map(m => m.toUpperCase()).map(m => m === "CONTROL" ? "CTRL" : m === "META" || m === "WIN" ? "SUPER" : m)
        let key = parts[parts.length - 1] ?? ""
        const symbol = { "/": "slash", ";": "semicolon", "'": "apostrophe", "[": "bracketleft", "]": "bracketright",
                         "-": "minus", "=": "equal", ",": "comma", ".": "period", "`": "grave", "\\": "backslash" }
        if (symbol[key]) key = symbol[key]
        else if (key.length === 1) key = key.toUpperCase()
        else { const k = Object.keys(codes).find(n => n.toLowerCase() === key.toLowerCase()); if (k) key = k }
        mods.sort((a, b) => order.indexOf(a) - order.indexOf(b))
        return { mods: mods, key: key }
    }
    function write(mods, key) { return mods.concat([key]).join(" + ") }
    // one way of writing keys: modifiers in order, the key's own name
    function canon(keys) { const p = parse(keys); return write(p.mods, p.key) }

    // what a key event is, as keys.json writes it ("CTRL + SHIFT + N"), or "" (a modifier alone,
    // a key without a name here)
    function mods(event) {
        const m = event.modifiers, out = []
        if (m & Qt.MetaModifier) out.push("SUPER")
        if (m & Qt.ControlModifier) out.push("CTRL")
        if (m & Qt.AltModifier) out.push("ALT")
        if (m & Qt.ShiftModifier) out.push("SHIFT")
        return out
    }
    function name(event) {
        const key = byCode[event.nativeScanCode - 8]
        return key ? write(mods(event), key) : ""
    }

    // as the Settings app and the launcher show keys: "SUPER + SHIFT + {n}" -> "Super+Shift+1–5"
    readonly property var shown: ({
        Escape: "Esc", BackSpace: "Backspace", Return: "Enter", KP_Enter: "Keypad Enter", space: "Space",
        minus: "-", equal: "=", bracketleft: "[", bracketright: "]", semicolon: ";", apostrophe: "'",
        grave: "`", backslash: "\\", comma: ",", period: ".", slash: "/", Up: "↑", Down: "↓",
        Left: "←", Right: "→", Prior: "PgUp", Next: "PgDn",
        "{dir}": "H J K L", "{arrow}": "← ↓ ↑ →",
    })
    readonly property var modNames: ({ SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" })
    function show(keys) {
        const p = parse(keys)
        const key = p.key === "{n}" ? "1–" + desktops : shown[p.key] ?? p.key
        return p.mods.map(m => modNames[m] ?? m).concat([key]).join("+")
    }

    // ---- the apps' keys -------------------------------------------------------------------
    // without keys.json (unreadable): the launcher's plain keys still work
    readonly property var fallback: ({
        launcher: { "launcher.run": ["Return", "KP_Enter"], "launcher.close": ["Escape"],
                    "launcher.next": ["Down"], "launcher.prev": ["Up"], "launcher.complete": ["Tab"] },
    })
    readonly property var apps: {
        const out = {}
        const given = model.apps ?? {}
        for (const app of Object.keys(given).concat(Object.keys(fallback))) {
            if (out[app]) continue
            const acts = given[app] ? given[app].actions ?? {} : null
            out[app] = {}
            if (acts) for (const a in acts) out[app][a] = (acts[a].keys ?? []).map(canon)
            else for (const a in fallback[app]) out[app][a] = fallback[app][a]
        }
        return out
    }

    function action(app, event) {
        const k = name(event), acts = apps[app] ?? {}
        if (!k) return ""
        for (const a in acts) if (acts[a].includes(k)) return a
        return ""
    }

    // whether this event types a character (no Ctrl/Alt/Super): the Settings app's search lets
    // those through
    function plain(event) { return !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && event.text !== "" && event.text >= " " && event.text !== "\x7f" }

    // an action's first key, shown ("Super+Return"), desktop or app
    function label(action) {
        for (const s of model.sections ?? []) if (s.actions && s.actions[action]) return first(s.actions[action])
        for (const app in model.apps ?? {}) { const a = model.apps[app].actions ?? {}; if (a[action]) return first(a[action]) }
        return ""
    }
    function first(def) { return def.keys && def.keys.length ? show(def.keys[0]) : "" }
}

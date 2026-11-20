// The keys of None's own apps (the launcher, the Settings app), set in tty/keys.toml (layers with
// `app`). mackeys writes them to ~/.local/state/mackeys/keymap.json as the keys each app gets
// (Cmd arrives as Ctrl, physical Ctrl as Super), by the key's Linux code, so they work on any
// layout. tty/settings uses this file too (a link).
//   AppKeys.action("launcher", event)  the action those keys are ("launcher.next"), or ""
//   AppKeys.label("launcher.favorite") its first key as on a Mac ("⌃ F"), or ""
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // keymap.json, read when first asked (a key can come right after start); a file caught
    // half-written doesn't parse: the last good one stays
    readonly property var last: ({ good: {} })   // changing it notifies nothing: no binding loop
    readonly property var model: {
        try { last.good = JSON.parse(file.text()) } catch (e) {}
        return last.good
    }
    readonly property var apps: model.apps ?? {}
    readonly property var rows: [].concat(...(model.groups ?? []).map(g => g.rows))

    // without mackeys' keymap (it hasn't run yet): the launcher's plain keys still work
    readonly property var fallback: ({
        launcher: {
            "launcher.run": [{ mods: [], code: 28 }, { mods: [], code: 96 }],
            "launcher.close": [{ mods: [], code: 1 }],
            "launcher.next": [{ mods: [], code: 108 }],
            "launcher.prev": [{ mods: [], code: 103 }],
            "launcher.complete": [{ mods: [], code: 15 }],
        },
    })

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/mackeys/keymap.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // as mackeys writes them: sorted, from alt altgr ctrl shift super
    function mods(event) {
        const m = event.modifiers, out = []
        if (m & Qt.AltModifier) out.push("alt")
        if (m & Qt.ControlModifier) out.push("ctrl")
        if (m & Qt.ShiftModifier) out.push("shift")
        if (m & Qt.MetaModifier) out.push("super")
        return out.join("+")
    }

    function keysOf(app) { return apps[app] ?? fallback[app] ?? {} }

    function action(app, event) {
        const code = event.nativeScanCode - 8, m = mods(event), acts = keysOf(app)
        for (const name in acts)
            if (acts[name].some(k => k.code === code && k.mods.join("+") === m)) return name
        return ""
    }

    // whether an action's keys include this event's key without Ctrl/Alt/Super (typing it would
    // type a character: the Settings app's search lets those through)
    function plain(event) { return !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && event.text !== "" && event.text >= " " && event.text !== "\x7f" }

    function label(action) {
        const r = rows.find(r => r.action === action)
        return r && r.keysLabel.length ? r.keysLabel[0] : ""
    }
}

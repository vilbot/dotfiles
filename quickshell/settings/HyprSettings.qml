// Hyprland's options, animations and displays as the settings window sees and changes them.
// - Live values come from hyprctl. A change applies at once through hypr/settings.lua
//   (`Settings.apply_json`) and is saved to hypr/settings.json, which Hyprland applies at start.
// - reset() drops a saved value and reloads Hyprland, so hyprland.lua's own value comes back.
// - Display changes revert by themselves after 15 s unless kept, like on a Mac.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "schema.js" as Schema

Singleton {
    id: root

    property var values: ({})          // option -> live value (colors as "RRGGBBAA")
    property var kinds: ({})           // option -> "int" | "float" | "bool" | "str" | "color" | "vec2"
    property var meta: ({})            // option -> its `hyprctl descriptions` entry
    property var anims: ({})           // leaf -> { overridden, enabled, speed, curve, style }
    property var monitors: []          // hyprctl monitors -j
    property var saved: ({ options: {}, animations: {}, monitors: {} })   // settings.json
    property var curves: []            // hypr/curves.json: [{ name, label }]

    readonly property string dir: Quickshell.env("HOME") + "/.config/hypr/"

    function refresh() { optionReader.running = true; monitorReader.running = true; animReader.running = true }

    // ---- reading ---------------------------------------------------------------------------
    // "88000000" (AARRGGBB, as Hyprland reports colors) -> "RRGGBBAA"
    function argbToRgba(s) { return (s.slice(2) + s.slice(0, 2)).toLowerCase() }

    Process {
        id: optionReader
        command: ["sh", "-c", Schema.options().map(o => "hyprctl getoption " + o.key + " -j").join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}, k = {}
                const colorKeys = Schema.options().filter(o => o.color).map(o => o.key)
                // one JSON object per option, possibly over several lines
                for (const chunk of text.split(/\n(?=\{)/)) {
                    let j
                    try { j = JSON.parse(chunk) } catch (e) { continue }
                    const key = j.option
                    if (j.gradient !== undefined) { v[key] = root.argbToRgba(j.gradient.split(" ")[0]); k[key] = "color" }
                    else if (j.int !== undefined && colorKeys.includes(key)) {
                        v[key] = root.argbToRgba((j.int >>> 0).toString(16).padStart(8, "0")); k[key] = "color"
                    }
                    else if (j.css !== undefined) { v[key] = Number(j.css.split(" ")[0]); k[key] = "int" }
                    else if (j.int !== undefined) { v[key] = j.int; k[key] = "int" }
                    else if (j.float !== undefined) { v[key] = j.float; k[key] = "float" }
                    else if (j.bool !== undefined) { v[key] = j.bool; k[key] = "bool" }
                    else if (j.str !== undefined) { v[key] = j.str === "[[EMPTY]]" ? "" : j.str; k[key] = "str" }
                    else if (j.vec2 !== undefined) { v[key] = j.vec2; k[key] = "vec2" }
                }
                root.values = v
                root.kinds = k
            }
        }
    }
    Process {
        running: true
        command: ["hyprctl", "descriptions", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                for (const d of JSON.parse(text)) m[d.name] = d
                root.meta = m
            }
        }
    }
    Process {
        id: animReader
        command: ["hyprctl", "animations", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const a = {}
                for (const x of JSON.parse(text)[0])
                    a[x.name] = { overridden: x.overridden, enabled: x.enabled, speed: x.speed, style: x.style,
                                  curve: x.bezier.replace(/^spring:/, "") }
                root.anims = a
            }
        }
    }
    Process {
        id: monitorReader
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: root.monitors = JSON.parse(text) }
    }
    FileView {
        path: root.dir + "curves.json"
        onLoaded: root.curves = JSON.parse(text())
    }

    FileView {
        id: store
        path: root.dir + "settings.json"
        atomicWrites: true
        onLoaded: {
            try { root.saved = Object.assign({ options: {}, animations: {}, monitors: {} }, JSON.parse(text())) }
            catch (e) { console.warn("settings.json:", e) }
        }
        // a reset was just written: reload Hyprland now that it's on disk
        onSaved: if (root.reloadAfterSave) { root.reloadAfterSave = false; reloader.running = true }
    }
    function reload() { store.reload(); refresh() }

    // ---- writing ---------------------------------------------------------------------------
    function sorted(o) {
        if (o === null || typeof o !== "object" || Array.isArray(o)) return o
        const out = {}
        for (const k of Object.keys(o).sort()) out[k] = sorted(o[k])
        return out
    }
    function save() { store.setText(JSON.stringify(sorted(saved), null, 4) + "\n") }
    // the same shape as settings.json, applied live; the long brackets keep the JSON as it is
    function apply(changes) {
        Quickshell.execDetached(["hyprctl", "eval", "Settings.apply_json([==[" + JSON.stringify(changes) + "]==])"])
    }
    function savedPart(part, key, value) {
        const s = Object.assign({}, saved)
        s[part] = Object.assign({}, s[part])
        if (value === undefined) delete s[part][key]
        else s[part][key] = value
        saved = s
    }

    function overridden(key) { return saved.options[key] !== undefined }
    function set(opt, v) {
        if (opt.resetValue !== undefined && v === opt.resetValue) { reset(opt); return }
        const kind = kinds[opt.key]
        if (kind === "int") v = Math.round(v)
        const stored = kind === "color" ? "rgba(" + v + ")" : v
        const vals = Object.assign({}, values); vals[opt.key] = v; values = vals
        savedPart("options", opt.key, stored)
        pending.options[opt.key] = stored
        applyTimer.restart()
        saveTimer.restart()
    }
    function reset(opt) {
        savedPart("options", opt.key, undefined)
        reloadAfterSave = true
        save()
    }

    // what a leaf does now: a leaf that isn't set does what its parent does
    function anim(leaf) {
        const info = Schema.animLeaves.find(l => l.leaf === leaf)
        const a = anims[leaf]
        if (a && a.overridden) return a
        if (info && info.parent) return Object.assign({}, anim(info.parent), { overridden: false, style: a?.style ?? "" })
        return a ?? { enabled: true, speed: 10, curve: "default", style: "" }
    }
    function animOverridden(leaf) { return saved.animations[leaf] !== undefined }
    function setAnim(leaf, changes) {
        const cur = anim(leaf)
        const next = Object.assign({ enabled: cur.enabled, speed: Math.round(cur.speed * 100) / 100,
                                     curve: cur.curve || "default", style: cur.style ?? "" }, changes)
        const an = Object.assign({}, anims); an[leaf] = Object.assign({ overridden: true }, next); anims = an
        savedPart("animations", leaf, next)
        pending.animations[leaf] = next
        applyTimer.restart()
        saveTimer.restart()
    }
    function resetAnim(leaf) {
        savedPart("animations", leaf, undefined)
        reloadAfterSave = true
        save()
    }

    property var pending: ({ options: {}, animations: {} })
    Timer {             // a slider drag becomes one hyprctl call every 50 ms
        id: applyTimer
        interval: 50
        onTriggered: { root.apply(root.pending); root.pending = { options: {}, animations: {} } }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: root.save() }
    property bool reloadAfterSave: false
    Process {           // returns once the config is applied
        id: reloader
        command: ["hyprctl", "reload"]
        onExited: root.refresh()
    }

    // ---- displays --------------------------------------------------------------------------
    function monitorKey(m) { return "desc:" + m.make + " " + m.model }
    function modeString(w, h, r) { return w + "x" + h + "@" + r.toFixed(2) }
    function applyMonitor(m, mode, scale) {
        const monitors = {}
        monitors[monitorKey(m)] = { mode: mode, scale: scale }
        apply({ monitors: monitors })
        monitorRereadTimer.restart()
    }
    Timer { id: monitorRereadTimer; interval: 1500; onTriggered: monitorReader.running = true }

    property var trial: null           // { monitor, mode, scale, oldMode, oldScale }, waiting for "Keep"
    property int trialLeft: 0
    function tryMonitor(m, mode, scale) {
        if (trial) return
        trial = { monitor: m, mode: mode, scale: scale, oldMode: modeString(m.width, m.height, m.refreshRate), oldScale: m.scale }
        trialLeft = 15
        applyMonitor(m, mode, scale)
        trialTimer.restart()
    }
    function keepTrial() {
        savedPart("monitors", monitorKey(trial.monitor), { mode: trial.mode, scale: trial.scale })
        trial = null
        trialTimer.stop()
        save()
    }
    function revertTrial() {
        applyMonitor(trial.monitor, trial.oldMode, trial.oldScale)
        trial = null
        trialTimer.stop()
    }
    Timer {
        id: trialTimer
        interval: 1000
        repeat: true
        onTriggered: { root.trialLeft -= 1; if (root.trialLeft <= 0) root.revertTrial() }
    }

    function shown(opt) { return !opt.when || opt.when.in.includes(values[opt.when.key]) }
}

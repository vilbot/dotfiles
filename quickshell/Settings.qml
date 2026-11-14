// Settings window for Hyprland options, animations and displays.
// - Shows the live values (`hyprctl getoption`, `hyprctl animations`) and applies changes at once
//   (`hyprctl eval`). Ranges, choices and the small descriptions come from Hyprland itself
//   (`hyprctl descriptions`), so an entry in `pages` only needs a key and a label.
// - Saves what you change to hypr/settings.lua (via ~/.config/hypr), which hyprland.lua applies
//   last, so it survives restarts. "default" on a row drops the override and reloads Hyprland.
// - Display changes ask to be kept and revert by themselves after 15 s, like on a Mac.
// Open from the control center ("Settings…") or `qs ipc call settings toggle` (or `page <name>`).
//
// Entry fields: key (hyprctl option name), label; optional: choices [[value, label], ...]
// (otherwise taken from Hyprland's map), labels {name: label} (rename mapped choices), min, max,
// step, percent, unit, zero (text for 0), color (an int option that is a color), when {key, in}
// (show only while another option has one of these values), resetValue (a value Hyprland
// reports but won't accept back; picking it removes the override). { heading: "..." } rows
// group the entries after them.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property var variantIs: v => ({ key: "decoration:blur:variant", in: v })
    readonly property var pages: [
        { name: "Windows", options: [
            { key: "general:gaps_in", label: "Gap between windows", min: 0, max: 40 },
            { key: "general:gaps_out", label: "Gap at the screen edge", min: 0, max: 80 },
            { key: "general:border_size", label: "Border thickness", max: 10, unit: " px" },
            { key: "decoration:rounding", label: "Corner rounding", max: 30 },
            { key: "decoration:rounding_power", label: "Corner shape", step: 0.1 },
            { key: "decoration:border_part_of_window", label: "Border counts as window" },
            { key: "general:resize_on_border", label: "Resize by dragging a border" },
            { key: "general:extend_border_grab_area", label: "Border grab area", max: 40, unit: " px" },
            { heading: "Transparency and dimming" },
            { key: "decoration:active_opacity", label: "Focused window opacity", min: 0.3, percent: true },
            { key: "decoration:inactive_opacity", label: "Other windows' opacity", min: 0.3, percent: true },
            { key: "decoration:fullscreen_opacity", label: "Fullscreen opacity", min: 0.3, percent: true },
            { key: "decoration:dim_inactive", label: "Dim other windows" },
            { key: "decoration:dim_strength", label: "Dim strength", percent: true },
            { key: "decoration:dim_modal", label: "Dim behind dialogs" },
            { heading: "Floating windows" },
            { key: "general:snap:enabled", label: "Snap to edges and windows" },
            { key: "general:snap:window_gap", label: "Snap distance to windows", max: 50, unit: " px" },
            { key: "general:snap:monitor_gap", label: "Snap distance to edges", max: 50, unit: " px" },
            { key: "general:snap:respect_gaps", label: "Snap keeps the gaps" },
        ] },
        { name: "Tiling", options: [
            { key: "general:layout", label: "Layout",
              choices: [["dwindle", "Dwindle"], ["master", "Master"], ["scrolling", "Scrolling"], ["monocle", "Monocle"]] },
            { heading: "Dwindle", when: { key: "general:layout", in: ["dwindle"] } },
            { key: "dwindle:preserve_split", label: "Keep split direction", when: { key: "general:layout", in: ["dwindle"] } },
            { key: "dwindle:smart_split", label: "Split where the mouse is", when: { key: "general:layout", in: ["dwindle"] } },
            { key: "dwindle:force_split", label: "New windows go", when: { key: "general:layout", in: ["dwindle"] },
              labels: { follow_mouse: "Toward the mouse", left: "Left / top", right: "Right / bottom" } },
            { key: "dwindle:default_split_ratio", label: "Split ratio", when: { key: "general:layout", in: ["dwindle"] } },
            { key: "dwindle:smart_resizing", label: "Resize from the nearest edge", when: { key: "general:layout", in: ["dwindle"] } },
            { heading: "Master", when: { key: "general:layout", in: ["master"] } },
            { key: "master:mfact", label: "Master size", percent: true, when: { key: "general:layout", in: ["master"] } },
            { key: "master:orientation", label: "Master side", when: { key: "general:layout", in: ["master"] },
              choices: [["left", "Left"], ["right", "Right"], ["top", "Top"], ["bottom", "Bottom"], ["center", "Center"]] },
            { key: "master:new_status", label: "New windows become", when: { key: "general:layout", in: ["master"] },
              choices: [["slave", "Stack"], ["master", "Master"], ["inherit", "Like the focused one"]] },
            { key: "master:new_on_top", label: "New windows on top of the stack", when: { key: "general:layout", in: ["master"] } },
        ] },
        { name: "Blur", options: [
            { key: "decoration:blur:enabled", label: "Blur behind translucent things" },
            { key: "decoration:blur:variant", label: "Style",
              labels: { kawase: "Classic", frost: "Frost", ripple: "Ripple", drops: "Drops", water: "Water",
                        fluid_jar: "Fluid jar", prism: "Prism", heat_shimmer: "Heat shimmer",
                        acrylic: "Acrylic", aurora: "Aurora", haze: "Haze" } },
            { key: "decoration:blur:size", label: "Size", max: 30 },
            { key: "decoration:blur:passes", label: "Passes", max: 6 },
            { key: "decoration:blur:noise", label: "Noise", max: 0.2 },
            { key: "decoration:blur:contrast", label: "Contrast" },
            { key: "decoration:blur:brightness", label: "Brightness" },
            { key: "decoration:blur:vibrancy", label: "Vibrancy" },
            { key: "decoration:blur:vibrancy_darkness", label: "Vibrancy in dark areas" },
            { key: "decoration:blur:ignore_opacity", label: "Ignore window opacity" },
            { key: "decoration:blur:xray", label: "X-ray (floating sees the wallpaper)" },
            { key: "decoration:blur:proportional", label: "Blur follows transparency" },
            { key: "decoration:blur:popups", label: "Blur menus and popups" },
            { key: "decoration:blur:special", label: "Blur behind the scratchpad" },

            { heading: "Glass", when: variantIs([1, 6, 10]) },
            { key: "decoration:blur:glass:refraction", label: "Refraction", when: variantIs([1, 6, 10]) },
            { key: "decoration:blur:glass:size", label: "Pattern size", max: 200, when: variantIs([1, 6, 10]) },
            { key: "decoration:blur:glass:roughness", label: "Roughness", when: variantIs([1, 6, 10]) },
            { heading: "Haze", when: variantIs([10]) },
            { key: "decoration:blur:haze:intensity", label: "Sheen", when: variantIs([10]) },
            { key: "decoration:blur:haze:iridescence", label: "Iridescence", when: variantIs([10]) },
            { heading: "Acrylic", when: variantIs([8]) },
            { key: "decoration:blur:acrylic:refraction", label: "Refraction", when: variantIs([8]) },
            { key: "decoration:blur:acrylic:bulb", label: "Curved edge", when: variantIs([8]) },
            { key: "decoration:blur:acrylic:clarity", label: "Clarity", when: variantIs([8]) },
            { key: "decoration:blur:acrylic:aberration", label: "Color fringing", when: variantIs([8]) },
            { key: "decoration:blur:acrylic:tint", label: "Tint", color: true, when: variantIs([8]) },
            { heading: "Aurora", when: variantIs([9]) },
            { key: "decoration:blur:aurora:speed", label: "Speed", when: variantIs([9]) },
            { key: "decoration:blur:aurora:intensity", label: "Intensity", when: variantIs([9]) },
            { key: "decoration:blur:aurora:color1", label: "First color", color: true, when: variantIs([9]) },
            { key: "decoration:blur:aurora:color2", label: "Second color", color: true, when: variantIs([9]) },
            { heading: "Ripple (click a window)", when: variantIs([2]) },
            { key: "decoration:blur:ripple:strength", label: "Strength", when: variantIs([2]) },
            { key: "decoration:blur:ripple:radius", label: "Radius", when: variantIs([2]) },
            { key: "decoration:blur:ripple:width", label: "Wave width", when: variantIs([2]) },
            { key: "decoration:blur:ripple:duration", label: "Duration", unit: " s", when: variantIs([2]) },
            { heading: "Water (follows the mouse)", when: variantIs([4]) },
            { key: "decoration:blur:water:strength", label: "Strength", when: variantIs([4]) },
            { key: "decoration:blur:water:radius", label: "Pointer radius", max: 200, when: variantIs([4]) },
            { key: "decoration:blur:water:speed", label: "Speed", when: variantIs([4]) },
            { key: "decoration:blur:water:damping", label: "Damping", when: variantIs([4]) },
            { key: "decoration:blur:water:duration", label: "Duration", unit: " s", when: variantIs([4]) },
            { heading: "Drops", when: variantIs([3]) },
            { key: "decoration:blur:drops:speed", label: "Speed (0 = still)", when: variantIs([3]) },
            { heading: "Heat shimmer", when: variantIs([7]) },
            { key: "decoration:blur:heat_shimmer:speed", label: "Speed (0 = still)", when: variantIs([7]) },
            { heading: "Fluid jar", when: variantIs([5]) },
            { key: "decoration:blur:fluid_jar:color", label: "Color", color: true, when: variantIs([5]) },
            { key: "decoration:blur:fluid_jar:fill_amount", label: "Fill", percent: true, when: variantIs([5]) },
            { key: "decoration:blur:fluid_jar:speed", label: "Speed", when: variantIs([5]) },
            { key: "decoration:blur:fluid_jar:mass", label: "Mass", when: variantIs([5]) },
            { key: "decoration:blur:fluid_jar:turbulence", label: "Turbulence", when: variantIs([5]) },
            { key: "decoration:blur:fluid_jar:distortion", label: "Distortion", when: variantIs([5]) },
            { key: "decoration:blur:fluid_jar:precision", label: "Precision", when: variantIs([5]) },
        ] },
        { name: "Shadows & Glow", options: [
            { key: "decoration:shadow:enabled", label: "Window shadows" },
            { key: "decoration:shadow:range", label: "Size", max: 80 },
            { key: "decoration:shadow:render_power", label: "Falloff" },
            { key: "decoration:shadow:sharp", label: "Sharp" },
            { key: "decoration:shadow:scale", label: "Scale" },
            { key: "decoration:shadow:color", label: "Color" },
            { key: "decoration:shadow:color_inactive", label: "Color, other windows" },
            { heading: "Glow" },
            { key: "decoration:glow:enabled", label: "Inner glow" },
            { key: "decoration:glow:range", label: "Size", max: 60 },
            { key: "decoration:glow:render_power", label: "Falloff" },
            { key: "decoration:glow:color", label: "Color" },
            { key: "decoration:glow:color_inactive", label: "Color, other windows" },
        ] },
        { name: "Motion", options: [
            { key: "animations:enabled", label: "Animations" },
            { key: "animations:workspace_wraparound", label: "Wrap slide between first and last desktop" },
            { key: "misc:animate_manual_resizes", label: "Animate resizing" },
            { key: "misc:animate_mouse_windowdragging", label: "Animate dragging" },
            { heading: "Motion blur" },
            { key: "decoration:motion_blur:enabled", label: "Motion blur on moving windows" },
            { key: "decoration:motion_blur:samples", label: "Samples", max: 32 },
            { heading: "Wobbly windows" },
            { key: "decoration:wobble:enabled", label: "Wobble when moved or resized" },
            { key: "decoration:wobble:intensity", label: "Intensity" },
            { key: "decoration:wobble:stiffness", label: "Stiffness", min: 10, max: 1000, step: 10 },
            { key: "decoration:wobble:damping", label: "Damping", max: 60, step: 0.5 },
            { key: "decoration:wobble:mass", label: "Mass", min: 0.1, max: 10, step: 0.1 },
            { key: "decoration:wobble:mesh", label: "Mesh detail" },
        ] },
        { name: "Animations", animations: true },
        { name: "Mouse & Keyboard", options: [
            { key: "input:repeat_delay", label: "Key repeat delay", min: 150, max: 1000, step: 25, unit: " ms" },
            { key: "input:repeat_rate", label: "Key repeat rate", min: 10, max: 80, unit: " / s" },
            { key: "input:sensitivity", label: "Mouse speed", min: -1, max: 1, step: 0.05 },
            { key: "input:accel_profile", label: "Mouse acceleration",
              choices: [["", "Default"], ["adaptive", "Adaptive"], ["flat", "Off"]], resetValue: "" },
            { key: "input:natural_scroll", label: "Natural scrolling" },
            { key: "input:follow_mouse", label: "Focus windows by", choices: [[2, "Clicking"], [1, "Hovering"]] },
            { heading: "Cursor" },
            { key: "cursor:inactive_timeout", label: "Hide the idle cursor after", min: 0, max: 10, step: 1, unit: " s", zero: "never" },
            { key: "cursor:hide_on_key_press", label: "Hide while typing" },
            { key: "cursor:zoom_factor", label: "Zoom around the cursor", min: 1, max: 4, step: 0.1, unit: "×" },
            { key: "cursor:no_warps", label: "Never move the cursor by itself" },
        ] },
        { name: "Displays", displays: true },
    ]
    readonly property var allOptions: [].concat(...pages.map(p => (p.options ?? []).filter(o => o.key)))

    // Animations page: leaves of Hyprland's animation tree, with their parent (unset leaves
    // inherit from it) and the styles they take.
    readonly property var winStyles: [["", "Default"], ["slide", "Slide"], ["popin 80%", "Pop in"], ["gnomed", "Genie"]]
    readonly property var wsStyles: [["", "Default"], ["slide", "Slide"], ["slidevert", "Slide up"], ["fade", "Fade"],
                                     ["slidefade 20%", "Slide + fade"], ["slidefadevert 20%", "Slide up + fade"]]
    readonly property var animLeaves: [
        { leaf: "global", label: "Everything", parent: null },
        { leaf: "windows", label: "Windows", parent: "global", styles: winStyles },
        { leaf: "windowsIn", label: "Windows opening", parent: "windows", styles: winStyles },
        { leaf: "windowsOut", label: "Windows closing", parent: "windows", styles: winStyles },
        { leaf: "windowsMove", label: "Windows moving", parent: "windows" },
        { leaf: "workspaces", label: "Switching desktops", parent: "global", styles: wsStyles },
        { leaf: "specialWorkspace", label: "Scratchpad", parent: "workspaces", styles: wsStyles },
        { leaf: "layers", label: "Bar, menus, panels", parent: "global",
          styles: [["", "Default"], ["slide", "Slide"], ["popin", "Pop in"], ["fade", "Fade"]] },
        { leaf: "fade", label: "Fades", parent: "global" },
        { leaf: "border", label: "Border color", parent: "global" },
        { leaf: "borderangle", label: "Border gradient turning", parent: "border",
          styles: [["", "Off"], ["once", "Once"], ["loop", "Loop"]] },
    ]
    // keep in sync with the hl.curve() list in hypr/hyprland.lua
    readonly property var curves: [["default", "Default"], ["linear", "Linear"], ["easeOutQuint", "Ease out"],
                                   ["easeInOutCubic", "Ease in-out"], ["almostLinear", "Almost linear"],
                                   ["quick", "Quick"], ["overshoot", "Overshoot"],
                                   ["easy", "Spring"], ["bouncy", "Bouncy spring"]]
    readonly property var springs: ["easy", "bouncy"]

    property int page: 0
    property var values: ({})          // key -> live value (colors as "RRGGBBAA")
    property var kinds: ({})           // key -> "int" | "float" | "bool" | "str" | "color" | "vec2"
    property var meta: ({})            // key -> hyprctl descriptions entry
    property var anims: ({})           // leaf -> { overridden, curve, enabled, speed, style }
    property var overrides: ({})       // key -> value saved in settings.lua
    property var animOverrides: ({})   // leaf -> { enabled, speed, curve, style } saved
    property var monitorRules: ({})    // "desc:<make> <model>" -> { mode, scale }
    property var monitors: []          // hyprctl monitors -j
    property var pendingApply: ({})    // key -> value, sent by applyTimer
    property var pendingAnims: ({})    // leaf -> animation, sent by applyTimer

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/settings.lua"

    IpcHandler {
        target: "settings"
        function toggle(): void { Panels.settingsOpen = !Panels.settingsOpen }
        function open(): void { Panels.settingsOpen = true }
        function close(): void { Panels.settingsOpen = false }
        // open at a page by name: `qs ipc call settings page Displays`
        function page(name: string): void {
            const i = root.pages.findIndex(p => p.name.toLowerCase() === name.toLowerCase())
            if (i >= 0) root.page = i
            Panels.settingsOpen = true
        }
    }

    // ---- reading -------------------------------------------------------------------------
    function refresh() { reader.running = true; monitorReader.running = true; animReader.running = true }

    // "88000000" (AARRGGBB, as Hyprland reports colors) -> "RRGGBBAA"
    function argbToRgba(s) { return (s.slice(2) + s.slice(0, 2)).toLowerCase() }

    Process {
        id: reader
        command: ["sh", "-c", root.allOptions.map(o => "hyprctl getoption " + o.key + " -j").join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}, k = {}
                const colorKeys = root.allOptions.filter(o => o.color).map(o => o.key)
                // one JSON object per option, possibly spanning lines
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
        id: metaReader
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
        id: store
        path: root.file
        atomicWrites: true
        onLoaded: root.parse(text())
        // a reset just rewrote the file: reload Hyprland now that it's on disk
        onSaved: if (root.reloadAfterSave) { root.reloadAfterSave = false; reloader.running = true }
    }

    // settings.lua -> overrides, animOverrides, monitorRules (the format writeFile() produces)
    function parse(src) {
        const o = {}, a = {}, m = {}
        let section = "options"
        const field = (s, name) => {
            const x = s.match(new RegExp(name + '\\s*=\\s*("[^"]*"|true|false|[-\\d.]+)'))
            return x ? root.luaValue(x[1]) : undefined
        }
        for (const line of src.split("\n")) {
            const sec = line.match(/^\s*(options|animations|monitors)\s*=/)
            if (sec) { section = sec[1]; continue }
            const e = line.match(/^\s*\["([^"]+)"\]\s*=\s*(.+?),?\s*$/)
            if (!e) continue
            if (section === "monitors")
                m[e[1]] = { mode: field(e[2], "mode") ?? "preferred", scale: field(e[2], "scale") ?? 1 }
            else if (section === "animations")
                a[e[1]] = { enabled: field(e[2], "enabled") ?? true, speed: field(e[2], "speed") ?? 5,
                            curve: field(e[2], "curve") ?? "default", style: field(e[2], "style") ?? "" }
            else o[e[1]] = luaValue(e[2])
        }
        overrides = o
        animOverrides = a
        monitorRules = m
    }
    function luaValue(s) {
        return s === "true" ? true : s === "false" ? false : s.startsWith('"') ? JSON.parse(s) : Number(s)
    }

    // ---- writing -------------------------------------------------------------------------
    function lua(v) {
        if (typeof v === "boolean") return v ? "true" : "false"
        if (typeof v === "number") return String(Math.round(v * 10000) / 10000)
        return JSON.stringify(String(v))
    }
    // "decoration:blur:size", 3 -> "{ decoration = { blur = { size = 3 } } }"
    function luaTable(key, v) {
        const parts = key.split(":")
        let s = parts[parts.length - 1] + " = " + lua(v)
        for (let i = parts.length - 2; i >= 0; i--) s = parts[i] + " = { " + s + " }"
        return "{ " + s + " }"
    }
    function luaAnim(leaf, a) {
        return "hl.animation({ leaf = " + lua(leaf) + ", enabled = " + lua(a.enabled) + ", speed = " + lua(a.speed)
             + (a.style ? ", style = " + lua(a.style) : "")
             + (springs.includes(a.curve) ? ", spring = " : ", bezier = ") + lua(a.curve) + " })"
    }

    function writeFile() {
        const out = [
            "-- Settings changed in the Quickshell settings app (quickshell/Settings.qml). hyprland.lua applies",
            "-- them last, over its own values. The app rewrites this file: keep one entry per line.",
            "return {",
            "    options = {",
        ]
        for (const k of Object.keys(overrides).sort())
            out.push('        ["' + k + '"] = ' + lua(overrides[k]) + ",")
        out.push("    },", "    animations = {")
        for (const k of Object.keys(animOverrides).sort()) {
            const a = animOverrides[k]
            out.push('        ["' + k + '"] = { enabled = ' + lua(a.enabled) + ", speed = " + lua(a.speed)
                     + ", curve = " + lua(a.curve) + ", style = " + lua(a.style) + " },")
        }
        out.push("    },", "    monitors = {")
        for (const k of Object.keys(monitorRules).sort()) {
            const r = monitorRules[k]
            out.push('        ["' + k + '"] = { mode = ' + lua(r.mode) + ", scale = " + lua(r.scale) + " },")
        }
        out.push("    },", "}", "")
        store.setText(out.join("\n"))
    }

    function set(opt, v) {
        if (opt.resetValue !== undefined && v === opt.resetValue) { reset(opt); return }
        const kind = kinds[opt.key]
        if (kind === "int") v = Math.round(v)
        const stored = kind === "color" ? "rgba(" + v + ")" : v
        const vals = Object.assign({}, values); vals[opt.key] = v; values = vals
        const ov = Object.assign({}, overrides); ov[opt.key] = stored; overrides = ov
        pendingApply[opt.key] = stored
        applyTimer.restart()
        saveTimer.restart()
    }
    function reset(opt) {
        const ov = Object.assign({}, overrides); delete ov[opt.key]; overrides = ov
        reloadAfterSave = true
        writeFile()
    }

    // effective animation of a leaf (unset leaves inherit from their parent)
    function anim(leaf) {
        const info = animLeaves.find(l => l.leaf === leaf)
        const a = anims[leaf]
        if (a && a.overridden) return a
        if (info && info.parent) return Object.assign({}, anim(info.parent), { overridden: false, style: a?.style ?? "" })
        return a ?? { enabled: true, speed: 10, curve: "default", style: "" }
    }
    function setAnim(leaf, changes) {
        const cur = anim(leaf)
        const next = { enabled: cur.enabled, speed: Math.round(cur.speed * 100) / 100, curve: cur.curve || "default",
                       style: cur.style ?? "" }
        Object.assign(next, changes)
        const an = Object.assign({}, anims); an[leaf] = Object.assign({ overridden: true }, next); anims = an
        const ao = Object.assign({}, animOverrides); ao[leaf] = next; animOverrides = ao
        pendingAnims[leaf] = next
        applyTimer.restart()
        saveTimer.restart()
    }
    function resetAnim(leaf) {
        const ao = Object.assign({}, animOverrides); delete ao[leaf]; animOverrides = ao
        reloadAfterSave = true
        writeFile()
    }

    Timer {             // coalesce slider drags into one hyprctl call
        id: applyTimer
        interval: 50
        onTriggered: {
            const code = Object.keys(root.pendingApply)
                .map(k => "hl.config(" + root.luaTable(k, root.pendingApply[k]) + ")")
                .concat(Object.keys(root.pendingAnims).map(l => root.luaAnim(l, root.pendingAnims[l])))
                .join("; ")
            root.pendingApply = {}
            root.pendingAnims = {}
            if (code) Quickshell.execDetached(["hyprctl", "eval", code])
        }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: root.writeFile() }
    // after a reset: reload so hyprland.lua's own value comes back, then re-read straight away
    // (hyprctl reload returns once the config is applied)
    property bool reloadAfterSave: false
    Process {
        id: reloader
        command: ["hyprctl", "reload"]
        onExited: root.refresh()
    }

    // ---- displays ------------------------------------------------------------------------
    function monitorKey(m) { return "desc:" + m.make + " " + m.model }
    function modeString(w, h, r) { return w + "x" + h + "@" + r.toFixed(2) }
    function applyMonitor(m, mode, scale) {
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.monitor({ output = " + lua(monitorKey(m)) + ", mode = " + lua(mode)
            + ", position = \"auto\", scale = " + lua(scale) + " })"])
        monitorRereadTimer.restart()
    }
    Timer { id: monitorRereadTimer; interval: 1500; onTriggered: monitorReader.running = true }

    // a display change waiting for "Keep" (reverts by itself)
    property var trial: null           // { monitor, mode, scale, oldMode, oldScale }
    property int trialLeft: 0
    function tryMonitor(m, mode, scale) {
        if (trial) return
        trial = { monitor: m, mode: mode, scale: scale,
                  oldMode: modeString(m.width, m.height, m.refreshRate), oldScale: m.scale }
        trialLeft = 15
        applyMonitor(m, mode, scale)
        trialTimer.restart()
    }
    function keepTrial() {
        const r = Object.assign({}, monitorRules)
        r[monitorKey(trial.monitor)] = { mode: trial.mode, scale: trial.scale }
        monitorRules = r
        trial = null
        trialTimer.stop()
        writeFile()
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

    function shown(opt) {
        if (!opt.when) return true
        return opt.when.in.includes(values[opt.when.key])
    }

    // ---- window --------------------------------------------------------------------------
    FloatingWindow {
        id: win
        title: "Settings"
        visible: Panels.settingsOpen
        implicitWidth: 900
        implicitHeight: 620
        color: Theme.paper
        onVisibleChanged: {
            if (visible) { store.reload(); root.refresh() }
            else Panels.settingsOpen = false
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Panels.settingsOpen = false
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // sidebar
            ColumnLayout {
                Layout.preferredWidth: 220
                Layout.fillWidth: false        // a child with fillWidth would make it grow
                Layout.fillHeight: true
                Layout.margins: 28
                spacing: 10
                Text { text: "Settings"; color: Theme.ink; font: Theme.heading; Layout.bottomMargin: 14 }
                Repeater {
                    model: root.pages
                    delegate: Text {
                        required property var modelData
                        required property int index
                        text: modelData.name
                        color: root.page === index || pageArea.containsMouse ? Theme.ink : Theme.inkDim
                        font: root.page === index ? Theme.text : Theme.textItalic
                        Rectangle {    // marker for the current page
                            visible: root.page === parent.index
                            anchors { right: parent.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            width: 12; height: 1; color: Theme.ink
                        }
                        MouseArea {
                            id: pageArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.page = parent.index; flick.contentY = 0 }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: "Saved to hypr/settings.lua.\nKeys: keys/keymap.toml."
                    wrapMode: Text.Wrap
                    color: Theme.inkFaint
                    font: Theme.textSmall
                }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.hairline }

            // page
            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.preferredWidth: 600
                Layout.fillHeight: true
                clip: true
                contentHeight: pageCol.implicitHeight + 56
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: pageCol
                    x: 36; y: 28
                    width: flick.width - 72
                    spacing: 0

                    Text {
                        text: root.pages[root.page].name
                        color: Theme.ink
                        font: Theme.heading
                        Layout.bottomMargin: 18
                    }

                    Repeater {
                        model: root.pages[root.page].options ?? []
                        delegate: Loader {
                            required property var modelData
                            Layout.fillWidth: true
                            visible: root.shown(modelData)
                            sourceComponent: modelData.heading ? headingRow : optionRow
                            onLoaded: item.opt = modelData
                        }
                    }

                    Repeater {
                        model: root.pages[root.page].animations ? root.animLeaves : []
                        delegate: AnimBlock { required property var modelData; info: modelData; settings: root }
                    }

                    Repeater {
                        model: root.pages[root.page].displays ? root.monitors : []
                        delegate: MonitorBlock { required property var modelData; monitor: modelData }
                    }
                }
            }
        }
    }

    // ---- rows --------------------------------------------------------------------------------
    component OptionRow: ColumnLayout {
        id: row
        property var opt: ({})
        readonly property var m: root.meta[opt.key] ?? {}
        readonly property string kind: root.kinds[opt.key] ?? ""
        readonly property var value: root.values[opt.key]
        readonly property bool overridden: root.overrides[opt.key] !== undefined
        // choices: given, or from Hyprland's map ([{name: value}, ...]) sorted by value
        readonly property var choices: opt.choices ?? (m.map ? m.map.map(e => { const n = Object.keys(e)[0]; return [e[n], (opt.labels ?? {})[n] ?? n] })
                                                           .sort((a, b) => a[0] - b[0]) : null)
        readonly property string type: choices ? "choice" : kind === "bool" ? "bool" : kind === "color" ? "color"
                                     : (kind === "int" || kind === "float") ? "number" : "other"
        readonly property real lo: opt.min ?? m.min ?? 0
        readonly property real hi: opt.max ?? m.max ?? 1
        readonly property real step: opt.step ?? (kind === "int" ? 1 : hi - lo <= 2 ? 0.01 : hi - lo <= 20 ? 0.1 : 1)
        readonly property int decimals: step >= 1 ? 0 : step >= 0.1 ? 1 : 2
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.maximumWidth: 250
                spacing: 1
                Text { text: row.opt.label ?? ""; color: Theme.ink; font: Theme.text; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.m.description ?? ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.inkFaint
                    font: Theme.textSmall
                }
            }

            Toggle {
                visible: row.type === "bool"
                checked: row.value === true
                onToggled: v => root.set(row.opt, v)
            }
            Slider {
                id: slider
                visible: row.type === "number"
                Layout.fillWidth: true
                value: ((row.value ?? 0) - row.lo) / (row.hi - row.lo)
                onMoved: v => {
                    const raw = row.lo + v * (row.hi - row.lo)
                    root.set(row.opt, Math.round(Math.round(raw / row.step) * row.step * 10000) / 10000)
                }
            }
            Text {
                visible: slider.visible
                Layout.preferredWidth: 64
                horizontalAlignment: Text.AlignRight
                text: row.value === undefined ? "" : row.opt.percent ? Math.round(row.value * 100) + "%"
                    : row.value === 0 && row.opt.zero ? row.opt.zero
                    : Number(row.value).toFixed(row.decimals) + (row.opt.unit ?? "")
                color: Theme.inkDim
                font: Theme.text
            }
            Flow {
                visible: row.type === "choice"
                Layout.fillWidth: true
                spacing: 16
                Repeater {
                    model: row.choices ?? []
                    delegate: Choice {
                        required property var modelData
                        text: modelData[1]
                        selected: row.value === modelData[0]
                        onClicked: root.set(row.opt, modelData[0])
                    }
                }
            }
            // color: swatch + RRGGBBAA, Enter to apply
            Row {
                visible: row.type === "color"
                spacing: 10
                Rectangle {
                    width: 22; height: 22; radius: 2
                    border { color: Theme.hairline; width: 1 }
                    // Qt wants #AARRGGBB
                    color: row.type === "color" && row.value ? "#" + row.value.slice(6, 8) + row.value.slice(0, 6) : "transparent"
                }
                Rectangle {
                    width: 96; height: 22
                    color: "transparent"
                    border { color: hex.activeFocus ? Theme.inkDim : Theme.hairline; width: 1 }
                    radius: 2
                    TextInput {
                        id: hex
                        anchors { fill: parent; leftMargin: 6 }
                        verticalAlignment: TextInput.AlignVCenter
                        text: row.type === "color" ? (row.value ?? "") : ""
                        maximumLength: 8
                        color: Theme.ink
                        font: Theme.textCaps
                        validator: RegularExpressionValidator { regularExpression: /[0-9a-fA-F]{0,8}/ }
                        onAccepted: {
                            const t = text.toLowerCase()
                            if (t.length === 6) root.set(row.opt, t + "ff")
                            else if (t.length === 8) root.set(row.opt, t)
                        }
                    }
                }
            }
            Item { Layout.fillWidth: row.type !== "number" && row.type !== "choice" }
            LinkText {
                text: "default"
                active: row.overridden
                opacity: row.overridden ? 1 : 0
                onClicked: root.reset(row.opt)
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
    }

    // italic word; selected = upright ink with an underline
    component Choice: Text {
        id: ch
        property bool selected
        signal clicked()
        color: selected || ca.containsMouse ? Theme.ink : Theme.inkDim
        font: selected ? Theme.text : Theme.textItalic
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 1 }
            height: 1; color: Theme.ink; visible: ch.selected
        }
        MouseArea {
            id: ca
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ch.clicked()
        }
    }

    component MonitorBlock: ColumnLayout {
        id: mb
        property var monitor
        Layout.fillWidth: true
        spacing: 0

        // "2560x1440@200.00Hz" -> { w, h, r }
        readonly property var modes: monitor.availableModes.map(s => {
            const m = s.match(/(\d+)x(\d+)@([\d.]+)/)
            return { w: Number(m[1]), h: Number(m[2]), r: Number(m[3]) }
        })
        readonly property var sizes: modes.map(m => m.w + "x" + m.h).filter((s, i, a) => a.indexOf(s) === i).slice(0, 8)
        readonly property string size: monitor.width + "x" + monitor.height
        readonly property var rates: modes.filter(m => m.w + "x" + m.h === size).map(m => m.r).sort((a, b) => b - a)
        function closeRate(r) { return Math.abs(r - monitor.refreshRate) < 0.05 }

        Text {
            text: mb.monitor.make + " " + mb.monitor.model
            color: Theme.ink
            font: Qt.font({ family: Theme.fontFamily, pixelSize: Theme.fontSize + 2, bold: true })
        }
        Text {
            text: mb.monitor.name + " · " + mb.size + " at " + Math.round(mb.monitor.refreshRate) + " Hz · scale " + mb.monitor.scale
            color: Theme.inkDim
            font: Theme.textItalic
            Layout.bottomMargin: 6
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

        MonitorRow {
            label: "Resolution"
            choices: mb.sizes.map(s => [s, s.replace("x", " × ")])
            isSelected: c => c === mb.size
            onPicked: c => {
                const [w, h] = c.split("x").map(Number)
                const best = mb.modes.filter(m => m.w === w && m.h === h).sort((a, b) => b.r - a.r)[0]
                root.tryMonitor(mb.monitor, root.modeString(w, h, best.r), mb.monitor.scale)
            }
        }
        MonitorRow {
            label: "Refresh rate"
            choices: mb.rates.map(r => [r, Math.round(r) + " Hz"])
            isSelected: c => mb.closeRate(c)
            onPicked: c => root.tryMonitor(mb.monitor, root.modeString(mb.monitor.width, mb.monitor.height, c), mb.monitor.scale)
        }
        MonitorRow {
            label: "Scale"
            choices: [[1, "100%"], [1.25, "125%"], [1.5, "150%"], [1.6, "160%"], [2, "200%"]]
            isSelected: c => Math.abs(c - mb.monitor.scale) < 0.01
            onPicked: c => root.tryMonitor(mb.monitor, root.modeString(mb.monitor.width, mb.monitor.height, mb.monitor.refreshRate), c)
        }

        // keep / revert
        RowLayout {
            visible: root.trial !== null && root.trial.monitor.name === mb.monitor.name
            Layout.fillWidth: true
            Layout.topMargin: 14
            spacing: 18
            Text {
                Layout.fillWidth: true
                text: "Keep this display setting? Reverting in " + root.trialLeft + " s."
                color: Theme.urgent
                font: Theme.textItalic
            }
            LinkText { text: "Keep"; onClicked: root.keepTrial() }
            LinkText { text: "Revert"; onClicked: root.revertTrial() }
        }
        Item { implicitHeight: 28 }
    }

    component MonitorRow: ColumnLayout {
        id: mr
        property string label
        property var choices: []
        property var isSelected: c => false
        signal picked(var choice)
        Layout.fillWidth: true
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            spacing: 16
            Text { text: mr.label; color: Theme.ink; font: Theme.text; Layout.preferredWidth: 250; Layout.alignment: Qt.AlignTop }
            Flow {
                Layout.fillWidth: true
                spacing: 18
                Repeater {
                    model: mr.choices
                    delegate: Choice {
                        required property var modelData
                        text: modelData[1]
                        selected: mr.isSelected(modelData[0])
                        onClicked: if (!selected) mr.picked(modelData[0])
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
    }

    // Loader components for the option rows (after the inline components they use)
    Component {
        id: headingRow
        ColumnLayout {
            id: hr
            property var opt: ({})
            spacing: 0
            Text {
                Layout.topMargin: 26
                Layout.bottomMargin: 4
                text: (hr.opt.heading ?? "").toUpperCase()
                color: Theme.inkFaint
                font: Theme.textCaps
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
        }
    }

    Component { id: optionRow; OptionRow {} }
}

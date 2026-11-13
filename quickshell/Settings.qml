// Settings window for Hyprland options and displays.
// - Shows the live values (`hyprctl getoption`) and applies changes at once (`hyprctl eval`).
// - Saves what you change to hypr/settings.lua (via ~/.config/hypr), which hyprland.lua applies
//   last, so it survives restarts. "default" on a row drops the override and reloads Hyprland.
// - Display changes ask to be kept and revert by themselves after 15 s, like on a Mac.
// Open from the control center ("Settings…") or `qs ipc call settings toggle`.
// To add an option: add an entry to `pages` (key = hyprctl option name, sections split by ":").
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property var pages: [
        { name: "Windows", options: [
            { key: "general:gaps_in", label: "Gap between windows", type: "int", min: 0, max: 30 },
            { key: "general:gaps_out", label: "Gap at the screen edge", type: "int", min: 0, max: 60 },
            { key: "general:border_size", label: "Border width", type: "int", min: 0, max: 8 },
            { key: "decoration:rounding", label: "Corner rounding", type: "int", min: 0, max: 24 },
            { key: "general:layout", label: "Tiling layout", type: "choice",
              choices: [["dwindle", "Dwindle"], ["master", "Master"]] },
            { key: "general:resize_on_border", label: "Resize by dragging a border", type: "bool" },
            { key: "decoration:active_opacity", label: "Focused window opacity", type: "float", min: 0.5, max: 1, step: 0.05, percent: true },
            { key: "decoration:inactive_opacity", label: "Other windows' opacity", type: "float", min: 0.5, max: 1, step: 0.05, percent: true },
            { key: "decoration:dim_inactive", label: "Dim other windows", type: "bool" },
            { key: "decoration:dim_strength", label: "Dim strength", type: "float", min: 0, max: 1, step: 0.05, percent: true },
        ] },
        { name: "Effects", options: [
            { key: "animations:enabled", label: "Animations", type: "bool" },
            { key: "decoration:blur:enabled", label: "Blur behind translucent things", type: "bool" },
            { key: "decoration:blur:size", label: "Blur size", type: "int", min: 1, max: 15 },
            { key: "decoration:blur:passes", label: "Blur passes", type: "int", min: 1, max: 4 },
            { key: "decoration:shadow:enabled", label: "Window shadows", type: "bool" },
            { key: "decoration:shadow:range", label: "Shadow size", type: "int", min: 0, max: 40 },
        ] },
        { name: "Mouse & Keyboard", options: [
            { key: "input:repeat_delay", label: "Key repeat delay", type: "int", min: 150, max: 1000, step: 25, unit: " ms" },
            { key: "input:repeat_rate", label: "Key repeat rate", type: "int", min: 10, max: 80, unit: " / s" },
            { key: "input:sensitivity", label: "Mouse speed", type: "float", min: -1, max: 1, step: 0.05 },
            { key: "input:accel_profile", label: "Mouse acceleration", type: "choice",
              choices: [["", "Default"], ["adaptive", "Adaptive"], ["flat", "Off"]] },
            { key: "input:natural_scroll", label: "Natural scrolling", type: "bool" },
            { key: "input:follow_mouse", label: "Focus follows the mouse", type: "choice",
              choices: [[1, "Yes"], [0, "No"]] },
            { key: "cursor:inactive_timeout", label: "Hide the idle cursor after", type: "float", min: 0, max: 10, step: 1, unit: " s", zero: "never" },
        ] },
        { name: "Displays", displays: true },
    ]
    readonly property var allOptions: [].concat(...pages.map(p => p.options ?? []))

    property int page: 0
    property var values: ({})          // key -> live value
    property var overrides: ({})       // key -> value saved in settings.lua
    property var monitorRules: ({})    // "desc:<make> <model>" -> { mode, scale }
    property var monitors: []          // hyprctl monitors -j
    property var pendingApply: ({})    // key -> value, sent by applyTimer

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/settings.lua"

    IpcHandler {
        target: "settings"
        function toggle(): void { Panels.settingsOpen = !Panels.settingsOpen }
        function open(): void { Panels.settingsOpen = true }
        function close(): void { Panels.settingsOpen = false }
    }

    // ---- reading -------------------------------------------------------------------------
    function refresh() { reader.running = true; monitorReader.running = true }

    Process {
        id: reader
        command: ["sh", "-c", root.allOptions.map(o => "hyprctl getoption " + o.key + " -j").join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue
                    let j
                    try { j = JSON.parse(line) } catch (e) { continue }
                    let x = j.int ?? j.float ?? j.bool ?? j.str
                    if (j.css !== undefined) x = Number(j.css.split(" ")[0])
                    if (x === "[[EMPTY]]") x = ""
                    v[j.option] = x
                }
                root.values = v
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
    }

    // settings.lua -> overrides + monitorRules (the format writeFile() produces)
    function parse(src) {
        const o = {}, m = {}
        let inMonitors = false
        for (const line of src.split("\n")) {
            if (/^\s*monitors\s*=/.test(line)) { inMonitors = true; continue }
            if (/^\s*options\s*=/.test(line)) { inMonitors = false; continue }
            const e = line.match(/^\s*\["([^"]+)"\]\s*=\s*(.+?),?\s*$/)
            if (!e) continue
            if (inMonitors) {
                const mode = e[2].match(/mode\s*=\s*"([^"]*)"/)
                const scale = e[2].match(/scale\s*=\s*([\d.]+)/)
                m[e[1]] = { mode: mode ? mode[1] : "preferred", scale: scale ? Number(scale[1]) : 1 }
            } else {
                const s = e[2]
                o[e[1]] = s === "true" ? true : s === "false" ? false
                        : s.startsWith('"') ? JSON.parse(s) : Number(s)
            }
        }
        overrides = o
        monitorRules = m
    }

    // ---- writing -------------------------------------------------------------------------
    function lua(v) {
        if (typeof v === "boolean") return v ? "true" : "false"
        if (typeof v === "number") return String(Math.round(v * 1000) / 1000)
        return JSON.stringify(String(v))
    }
    // "decoration:blur:size", 3 -> "decoration = { blur = { size = 3 } }"
    function luaTable(key, v) {
        const parts = key.split(":")
        let s = parts[parts.length - 1] + " = " + lua(v)
        for (let i = parts.length - 2; i >= 0; i--) s = parts[i] + " = { " + s + " }"
        return "{ " + s + " }"
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
        out.push("    },", "    monitors = {")
        for (const k of Object.keys(monitorRules).sort()) {
            const r = monitorRules[k]
            out.push('        ["' + k + '"] = { mode = ' + lua(r.mode) + ", scale = " + lua(r.scale) + " },")
        }
        out.push("    },", "}", "")
        store.setText(out.join("\n"))
    }

    function set(opt, v) {
        if (opt.type === "int") v = Math.round(v)
        const vals = Object.assign({}, values); vals[opt.key] = v; values = vals
        const ov = Object.assign({}, overrides); ov[opt.key] = v; overrides = ov
        pendingApply[opt.key] = v
        applyTimer.restart()
        saveTimer.restart()
    }
    function reset(opt) {
        const ov = Object.assign({}, overrides); delete ov[opt.key]; overrides = ov
        writeFile()
        reloadTimer.restart()
    }

    Timer {             // coalesce slider drags into one hyprctl call
        id: applyTimer
        interval: 50
        onTriggered: {
            const code = Object.keys(root.pendingApply)
                .map(k => "hl.config(" + root.luaTable(k, root.pendingApply[k]) + ")").join("; ")
            root.pendingApply = {}
            if (code) Quickshell.execDetached(["hyprctl", "eval", code])
        }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: root.writeFile() }
    Timer {             // after a reset: reload so hyprland.lua's own value comes back, then re-read
        id: reloadTimer
        interval: 300
        onTriggered: { Quickshell.execDetached(["hyprctl", "reload"]); rereadTimer.restart() }
    }
    Timer { id: rereadTimer; interval: 800; onTriggered: root.refresh() }

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
                            onClicked: root.page = parent.index
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
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: pageCol.implicitHeight + 56
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: pageCol
                    x: 36; y: 28
                    width: parent.width - 72
                    spacing: 0

                    Text {
                        text: root.pages[root.page].name
                        color: Theme.ink
                        font: Theme.heading
                        Layout.bottomMargin: 18
                    }

                    Repeater {
                        model: root.pages[root.page].options ?? []
                        delegate: OptionRow { required property var modelData; opt: modelData }
                    }

                    // displays page
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
        property var opt
        readonly property var value: root.values[opt.key]
        readonly property bool overridden: root.overrides[opt.key] !== undefined
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            spacing: 16

            Text { text: row.opt.label; color: Theme.ink; font: Theme.text; Layout.preferredWidth: 230 }

            // bool
            Toggle {
                visible: row.opt.type === "bool"
                checked: row.value === true
                onToggled: v => root.set(row.opt, v)
            }
            // int / float
            Slider {
                id: slider
                visible: row.opt.type === "int" || row.opt.type === "float"
                Layout.fillWidth: true
                readonly property real span: (row.opt.max ?? 1) - (row.opt.min ?? 0)
                value: ((row.value ?? 0) - (row.opt.min ?? 0)) / span
                onMoved: v => {
                    const step = row.opt.step ?? 1
                    const raw = (row.opt.min ?? 0) + v * span
                    root.set(row.opt, Math.round(Math.round(raw / step) * step * 1000) / 1000)
                }
            }
            Text {
                visible: slider.visible
                Layout.preferredWidth: 64
                horizontalAlignment: Text.AlignRight
                text: row.value === undefined ? "" : row.opt.percent ? Math.round(row.value * 100) + "%"
                    : row.value === 0 && row.opt.zero ? row.opt.zero
                    : (row.opt.type === "float" && !row.opt.unit ? Number(row.value).toFixed(2) : row.value) + (row.opt.unit ?? "")
                color: Theme.inkDim
                font: Theme.text
            }
            // choice
            Row {
                visible: row.opt.type === "choice"
                spacing: 18
                Repeater {
                    model: row.opt.choices ?? []
                    delegate: Choice {
                        required property var modelData
                        text: modelData[1]
                        selected: row.value === modelData[0]
                        onClicked: root.set(row.opt, modelData[0])
                    }
                }
            }
            Item { Layout.fillWidth: row.opt.type !== "int" && row.opt.type !== "float" }
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
            Text { text: mr.label; color: Theme.ink; font: Theme.text; Layout.preferredWidth: 230; Layout.alignment: Qt.AlignTop }
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
}

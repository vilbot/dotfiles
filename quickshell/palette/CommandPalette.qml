// (Not called Palette.qml: QtQuick already has a type named Palette.)
// Command palette: one search box for apps (and their actions like "New window"), open
// windows, settings pages and system commands, plus a calculator ("12*7" -> Enter copies 84).
// Cmd+Space (hypr/hyprland.lua: programs.launcher) or `qs ipc call palette toggle`.
// Up/Down (or Ctrl+N/P, Ctrl+J/K) choose, Enter runs, Esc closes. Things you run often rank higher (counts kept in
// ~/.local/state/quickshell/palette.json). Log out / restart / shut down ask for a second Enter.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.widgets
import "../settings/schema.js" as Schema

Scope {
    id: root
    property bool showing: false
    property string query: ""
    property int current: 0
    property string confirming: ""        // key of a command waiting for a second Enter
    property var usage: ({})              // item key -> times run
    readonly property int maxResults: 9

    function toggle() { if (showing) close(); else show() }
    function show() { query = ""; current = 0; confirming = ""; lastMouse = Qt.point(-1, -1); showing = true }
    function close() { showing = false }

    function move(d) { current = Math.max(0, Math.min(results.length - 1, current + d)) }

    IpcHandler {
        target: "palette"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.close() }
    }

    // ---- what can be found ---------------------------------------------------------------
    function sh(cmd) { return () => Quickshell.execDetached(["sh", "-c", cmd]) }

    readonly property var commands: [
        { name: "Control center", detail: "Sound, display, network, Bluetooth", icon: "preferences-system", run: () => { Panels.controlOpen = true } },
        { name: "Notifications", detail: "History", icon: "preferences-desktop-notification", run: () => { Panels.historyOpen = true } },
        { name: "Keyboard shortcuts", detail: "Opt + ?", icon: "preferences-desktop-keyboard", run: sh("qs ipc call keybinds open") },
        { name: "Settings", detail: "Hyprland settings", icon: "preferences-system", run: () => Panels.openSettings() },
    ].concat(Schema.pages.map(p => ({ name: "Settings: " + p.name, detail: p.detail, icon: p.icon,
                                      run: () => Panels.openSettings(p.name) }))).concat([
        { name: "System Settings", detail: "KDE", icon: "systemsettings", run: sh("systemsettings") },
        { name: "Wi-Fi on", icon: "network-wireless", run: sh("nmcli radio wifi on") },
        { name: "Wi-Fi off", icon: "network-wireless-disconnected", run: sh("nmcli radio wifi off") },
        { name: "Bluetooth on", icon: "preferences-system-bluetooth", run: sh("bluetoothctl power on") },
        { name: "Bluetooth off", icon: "preferences-system-bluetooth-inactive", run: sh("bluetoothctl power off") },
        { name: "Mute / unmute", detail: "Sound output", icon: "audio-volume-muted", run: sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
        { name: "Reload Hyprland", detail: "Re-read hypr/*.lua", icon: "view-refresh", run: sh("hyprctl reload") },
        { name: "Reload Quickshell", detail: "Bar, panels, this palette", icon: "view-refresh", run: () => Quickshell.reload(true) },
        { name: "Suspend", icon: "system-suspend", run: sh("systemctl suspend") },
        { name: "Log out", detail: "Leave Hyprland", icon: "system-log-out", confirm: true, run: sh(`hyprctl eval 'hl.dispatch(hl.dsp.exit())'`) },
        { name: "Restart", icon: "system-reboot", confirm: true, run: sh("systemctl reboot") },
        { name: "Shut down", icon: "system-shutdown", confirm: true, run: sh("systemctl poweroff") },
    ])

    // apps, their actions, windows and commands as one list of
    // { key, kind, name, detail, icon, words (extra search text), run, confirm }
    readonly property var everything: {
        const out = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            out.push({ key: "app:" + e.id, kind: "App", name: e.name, detail: e.genericName || e.comment,
                       icon: e.icon, words: [e.genericName, (e.keywords ?? []).join(" "), e.id].join(" "),
                       run: () => e.execute() })
            for (const a of e.actions)
                out.push({ key: "action:" + e.id + ":" + a.id, kind: "Action", name: e.name + ": " + a.name,
                           detail: "", icon: a.icon || e.icon, words: "", run: () => a.execute(), minor: true })
        }
        for (const c of commands)
            out.push({ key: "cmd:" + c.name, kind: "Command", name: c.name, detail: c.detail ?? "",
                       icon: c.icon, words: "", run: c.run, confirm: c.confirm ?? false })
        return out
    }
    readonly property var windows: Windows.all.map(t => ({
        key: "win:" + t.address, kind: "Window", name: t.title,
        detail: Windows.app(t) + " · desktop " + t.workspace.id,
        icon: Windows.appIcon(Windows.app(t)), words: Windows.app(t),
        run: () => Windows.focus(t)
    }))

    // ---- matching --------------------------------------------------------------------------
    function match(q, text) {
        if (!text) return 0
        const t = text.toLowerCase()
        if (t === q) return 100
        if (t.startsWith(q)) return 80
        if (t.includes(" " + q) || t.includes("-" + q) || t.includes(":" + q)) return 60
        if (t.includes(q)) return 40
        let i = 0                           // letters in order: "gc" finds "Google Chrome"
        for (const ch of t) if (ch === q[i]) i++
        return i === q.length ? 15 : 0
    }

    // "12*(3+4)" -> number, or null
    function calc(q) {
        if (!/^[\d\s+\-*/().,%^]+$/.test(q) || !/\d/.test(q) || !/[+\-*/%^]/.test(q)) return null
        try {
            const v = Function('"use strict"; return (' + q.replace(/,/g, ".").replace(/\^/g, "**") + ")")()
            return typeof v === "number" && isFinite(v) ? Math.round(v * 1e10) / 1e10 : null
        } catch (e) { return null }
    }

    readonly property var results: {
        const q = query.trim().toLowerCase()
        const boost = it => Math.min(usage[it.key] ?? 0, 25)
        if (q === "") {
            // nothing typed: open windows, then what you use most
            const used = everything.filter(it => usage[it.key]).sort((a, b) => boost(b) - boost(a))
            return windows.concat(used).slice(0, maxResults)
        }
        const out = []
        const n = calc(q)
        if (n !== null) out.push({ key: "calc", kind: "Calculator", name: "= " + n, detail: "Enter copies it",
                                   icon: "accessories-calculator", run: () => { Quickshell.clipboardText = String(n) }, s: 1000 })
        for (const it of windows.concat(everything)) {
            const s = Math.max(match(q, it.name), match(q, it.words) * 0.6, match(q, it.detail) * 0.4)
            if (s <= 0) continue
            out.push(Object.assign({}, it, { s: s - (it.minor ? 10 : 0) - (it.kind === "Window" ? 5 : 0) + boost(it) }))
        }
        return out.sort((a, b) => b.s - a.s).slice(0, maxResults)
    }
    // a new search starts at the top; other updates (a window title changing) keep the selection
    onQueryChanged: { current = 0; confirming = "" }
    onResultsChanged: current = Math.min(current, Math.max(0, results.length - 1))

    // hover selects only when the mouse really moves, not when a row appears under a still mouse
    property point lastMouse: Qt.point(-1, -1)
    function hovered(item, mouse, i) {
        const p = item.mapToItem(null, mouse.x, mouse.y)
        if (p.x === lastMouse.x && p.y === lastMouse.y) return
        const first = lastMouse.x < 0
        lastMouse = p
        if (!first) current = i
    }

    function run(i) {
        const it = results[i]
        if (!it) return
        if (it.confirm && confirming !== it.key) { confirming = it.key; return }
        const u = Object.assign({}, usage)
        if (it.key !== "calc") { u[it.key] = (u[it.key] ?? 0) + 1; usage = u; usageFile.setText(JSON.stringify(usage)) }
        close()
        it.run()
    }

    // ---- usage counts ----------------------------------------------------------------------
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    Process { running: true; command: ["mkdir", "-p", root.stateDir] }
    FileView {
        id: usageFile
        path: root.stateDir + "/palette.json"
        onLoaded: { try { root.usage = JSON.parse(text()) } catch (e) { root.usage = {} } }
    }

    // ---- window ----------------------------------------------------------------------------
    PanelWindow {
        screen: Screens.focused
        visible: root.showing
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-palette"
        WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Rectangle {
            id: panel
            width: 640
            height: col.implicitHeight + 2 * 20
            x: (parent.width - width) / 2
            y: parent.height * 0.2
            color: Theme.panel
            border { color: Theme.hairline; width: 1 }
            radius: 2
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 10

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    text: root.query
                    onTextEdited: root.query = text
                    color: Theme.ink
                    font: Qt.font({ family: Theme.fontFamily, pixelSize: 26, italic: true })
                    focus: root.showing
                    onVisibleChanged: if (visible) forceActiveFocus()
                    Connections {
                        target: root
                        function onShowingChanged() { if (root.showing) { input.text = ""; input.forceActiveFocus() } }
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.run(root.current)
                    Keys.onEnterPressed: root.run(root.current)
                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    // Ctrl+N/J down, Ctrl+P/K up. Physical Ctrl arrives as Super (Meta) through
                    // mackeys, as Ctrl without it.
                    Keys.onPressed: event => {
                        if (!(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) return
                        if (event.key === Qt.Key_N || event.key === Qt.Key_J) { root.move(1); event.accepted = true }
                        else if (event.key === Qt.Key_P || event.key === Qt.Key_K) { root.move(-1); event.accepted = true }
                    }
                    Keys.onTabPressed: root.current = (root.current + 1) % Math.max(1, root.results.length)

                    Text {
                        visible: input.text === ""
                        text: "Search apps, windows, settings…"
                        color: Theme.inkFaint
                        font: input.font
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline; visible: root.results.length > 0 }

                Repeater {
                    model: root.results
                    delegate: Item {
                        id: res
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.current
                        Layout.fillWidth: true
                        implicitHeight: 36

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: -8; anchors.rightMargin: -8
                            radius: Theme.radius
                            color: res.selected ? Theme.hover : "transparent"
                        }
                        Rectangle {     // ink marker on the chosen row
                            visible: res.selected
                            anchors { left: parent.left; leftMargin: -14; verticalCenter: parent.verticalCenter }
                            width: 2; height: 18; color: Theme.ink
                        }
                        RowLayout {
                            anchors.fill: parent
                            spacing: 12
                            AppIcon { implicitSize: 20; icon: res.modelData.icon ?? "" }
                            Text {
                                text: root.confirming === res.modelData.key ? res.modelData.name + "? Press Enter again" : res.modelData.name
                                elide: Text.ElideRight
                                Layout.maximumWidth: 360
                                color: root.confirming === res.modelData.key ? Theme.urgent : Theme.ink
                                font: Theme.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: res.modelData.detail ?? ""
                                elide: Text.ElideRight
                                color: Theme.inkFaint
                                font: Theme.textSmall
                            }
                            Text {
                                text: res.modelData.kind.toUpperCase()
                                color: Theme.inkFaint
                                font: Qt.font({ family: Theme.fontFamily, pixelSize: Theme.fontSize - 4, letterSpacing: 1.5 })
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => root.hovered(parent, mouse, res.index)
                            onClicked: root.run(res.index)
                        }
                    }
                }

                Text {
                    visible: root.query.trim() !== "" && root.results.length === 0
                    text: "Nothing found."
                    color: Theme.inkFaint
                    font: Theme.textItalic
                }
            }
        }
    }
}

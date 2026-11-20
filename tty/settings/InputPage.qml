// Keyboard & mouse: Hyprland's input options (Options.qml), with sliders, switches and choices.
// h / l (or the arrows) move the picked slider or choice, Enter flips a switch.
import QtQuick
import QtQuick.Layouts

Item {
    id: page
    property string query: ""
    property bool mouseLive: true
    property int current: 0
    readonly property string hints: "← → change   ⏎ switch   / search"
    readonly property string message: ""
    readonly property bool messageBad: false

    // kind: slider (from, to, step, unit, zero), switch, choice (choices)
    readonly property var options: [
        { heading: "Keyboard" },
        { key: "input:repeat_delay", label: "Key repeat delay", detail: "how long a key is held before it repeats",
          kind: "slider", from: 150, to: 1000, step: 25, unit: " ms" },
        { key: "input:repeat_rate", label: "Key repeat rate", detail: "repeats per second while held",
          kind: "slider", from: 10, to: 80, step: 1, unit: " /s" },
        { heading: "Mouse" },
        { key: "input:sensitivity", label: "Mouse speed", detail: "-1 slow, 1 fast",
          kind: "slider", from: -1, to: 1, step: 0.05 },
        { key: "input:accel_profile", label: "Acceleration", detail: "faster moves go further",
          kind: "choice", choices: [["", "default"], ["adaptive", "on"], ["flat", "off"]] },
        { key: "input:natural_scroll", label: "Natural scrolling", detail: "content follows the fingers", kind: "switch" },
        { key: "input:follow_mouse", label: "Focus windows by", detail: "",
          kind: "choice", choices: [[2, "clicking"], [1, "hovering"]] },
        { heading: "Cursor" },
        { key: "cursor:hide_on_key_press", label: "Hide while typing", detail: "", kind: "switch" },
        { key: "cursor:inactive_timeout", label: "Hide when still for", detail: "",
          kind: "slider", from: 0, to: 10, step: 1, unit: " s", zero: "never" },
    ]
    readonly property var shown: {
        const q = query.trim().toLowerCase()
        const rows = options.filter(o => o.key && (!q || q.split(/\s+/).every(w => (o.label + " " + o.detail + " " + o.key).toLowerCase().includes(w))))
        const out = []
        let heading = null
        for (const o of options) {
            if (o.heading) { heading = o; continue }
            if (!rows.includes(o)) continue
            if (heading) { out.push(heading); heading = null }
            out.push(o)
        }
        return out
    }
    readonly property var rows: shown.filter(o => o.key)
    readonly property var row: rows[current] ?? null
    onQueryChanged: current = 0

    function next() { if (current < rows.length - 1) current++ }
    function prev() { if (current > 0) current-- }
    function change(o, by) {
        if (!o) return
        const v = Options.get(o.key)
        if (o.kind === "slider") Options.set(o.key, Math.max(o.from, Math.min(o.to, +(v + by * o.step).toFixed(6))))
        else if (o.kind === "choice") {
            const i = Math.max(0, Math.min(o.choices.length - 1, o.choices.findIndex(c => c[0] === v) + by))
            Options.set(o.key, o.choices[i][0])
        }
        else if (o.kind === "switch") Options.set(o.key, by > 0)
    }
    function activate() { if (row && row.kind === "switch") Options.set(row.key, !Options.get(row.key)) }
    function lower() { change(row, -1) }
    function higher() { change(row, 1) }
    function addKey() {}
    function unbind() {}
    function back() { return false }
    function undo() {}
    function redo() {}

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: parent.width
            Repeater {
                model: page.shown
                delegate: Loader {
                    required property var modelData
                    width: col.width
                    property var opt: modelData
                    sourceComponent: modelData.heading ? heading : line
                }
            }
        }
    }

    Component {
        id: heading
        Item {
            height: 48
            Text {
                anchors { left: parent.left; leftMargin: Style.pad; bottom: parent.bottom; bottomMargin: 8 }
                text: parent.parent.opt.heading.toUpperCase()
                font: Style.heading
                color: Style.accent
            }
        }
    }
    Component {
        id: line
        Rectangle {
            id: r
            readonly property var o: parent.opt
            readonly property int index: page.rows.findIndex(x => x.key === o.key)
            readonly property bool picked: index === page.current
            readonly property var value: Options.values[o.key]
            height: o.detail ? 52 : Style.row + 6
            color: picked ? Style.raised : "transparent"
            Behavior on color { ColorAnimation { duration: Style.quick } }
            Rectangle {
                width: 3; height: parent.height
                color: Style.accent
                opacity: r.picked ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Style.quick } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: if (page.mouseLive) page.current = r.index
                onPositionChanged: page.current = r.index
                onClicked: { page.current = r.index; if (r.o.kind === "switch") Options.set(r.o.key, !r.value) }
            }
            RowLayout {
                anchors { fill: parent; leftMargin: Style.pad; rightMargin: Style.pad }
                spacing: 24
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: r.o.label; font: Style.font; color: r.picked ? Style.strong : Style.text }
                    Text { visible: !!r.o.detail; text: r.o.detail ?? ""; font: Style.small; color: Style.dim }
                }
                Slider {
                    visible: r.o.kind === "slider"
                    Layout.preferredWidth: Math.min(420, r.width * 0.5)
                    from: r.o.from ?? 0; to: r.o.to ?? 1; step: r.o.step ?? 1
                    unit: r.o.unit ?? ""; zero: r.o.zero ?? ""
                    value: typeof r.value === "number" ? r.value : 0
                    active: r.picked
                    onMoved: v => { page.current = r.index; Options.set(r.o.key, v) }
                }
                Switch {
                    visible: r.o.kind === "switch"
                    checked: !!r.value
                    active: r.picked
                    onToggled: c => { page.current = r.index; Options.set(r.o.key, c) }
                }
                Choice {
                    visible: r.o.kind === "choice"
                    choices: r.o.choices ?? []
                    value: r.value
                    active: r.picked
                    onPicked: v => { page.current = r.index; Options.set(r.o.key, v) }
                }
            }
        }
    }
}

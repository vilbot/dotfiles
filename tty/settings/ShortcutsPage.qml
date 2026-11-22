// Every action in tty/keys.json with its keys, by section, searchable by name or by keys.
// Click a key (or Enter on the row) and press new keys: Hyprland's binds are off meanwhile
// (Keymap.qml), so they do nothing else; Esc twice cancels, Esc and a pause records Esc. "+" (or a) adds one more key, Backspace removes the row's keys.
// Keys another action already has (in the same app, or on the desktop): Enter takes them over.
// Saved at once, Hyprland reloads (Ctrl+Z undoes).
import QtQuick
import QtQuick.Layouts

Item {
    id: page
    property string query: ""
    property bool mouseLive: true           // set by the window: the mouse moved since the last key
    property int current: 0
    readonly property string hints: rec ? "press the new keys   Esc Esc cancel"
        : ask ? "Enter " + ask.yes + "   Esc no"
        : "Enter record   a add   Backspace remove   Ctrl+Z undo   / search"

    // ---- what's shown ----------------------------------------------------------------------
    // rows that fit the search, and the list with section headings between them
    readonly property var shown: Keymap.rows.filter(r => Keymap.fits(r, query))
    readonly property var items: {
        const out = []
        let group = null
        shown.forEach((r, i) => {
            if (r.group !== group) { out.push({ heading: r.group }); group = r.group }
            out.push({ row: r, index: i })
        })
        return out
    }
    readonly property var row: shown[current] ?? null
    onShownChanged: if (current >= shown.length) current = Math.max(0, shown.length - 1)
    onQueryChanged: current = 0

    // ---- changing keys --------------------------------------------------------------------
    property var rec: null       // recording: { action, slot } (slot: which key, -1 one more, -2 all)
    property var ask: null       // waiting for Enter: { text, yes, go }
    property string message: ""
    property bool messageBad: false
    Timer { id: fade; interval: 4000; onTriggered: if (!page.messageBad) page.message = "" }
    function say(text, bad) { message = text; messageBad = !!bad; fade.restart() }
    Connections {
        target: Keymap
        function onErrorChanged() { if (Keymap.error) page.say(Keymap.error, true) }
        function onSaved() { if (!page.messageBad) page.say("saved   Ctrl+Z undo") }
    }

    // Enter on a row: its first key, or all of them when it has several, or one when it has none
    function slotFor(r) { return r.keys.length === 0 ? -1 : r.keys.length > 1 ? -2 : 0 }
    function record(r, slot) {
        if (!r || r.fixed) return
        ask = null
        rec = { action: r.action, slot: slot }
        Keymap.record(keys => { const was = rec; rec = null; if (keys) recorded(r, was.slot, keys) })
    }
    function cancel() { if (rec) Keymap.cancel() }

    // {n} rows take a digit, {dir} rows h j k l (or the arrows): the keys then stand for all
    function templated(r, keys) {
        const s = Keymap.split(keys)
        if (r.action.includes("{n}")) {
            if (!/^[1-9]$/.test(s.key)) return { error: "this one is for every desktop: press the modifiers with a number" }
            return { keys: AppKeys.write(s.mods, "{n}") }
        }
        if (r.action.includes("{dir}")) {
            if (["H", "J", "K", "L"].includes(s.key)) return { keys: AppKeys.write(s.mods, "{dir}") }
            if (["Left", "Down", "Up", "Right"].includes(s.key)) return { keys: AppKeys.write(s.mods, "{arrow}") }
            return { error: "this one is for every direction: press the modifiers with h j k l or an arrow" }
        }
        return { keys: keys }
    }

    function recorded(r, slot, raw) {
        const t = templated(r, raw)
        if (t.error) { say(t.error, true); return }
        let keys = r.keys.slice()
        if (slot === -2 || (slot === 0 && keys.length <= 1)) keys = [t.keys]
        else if (slot === -1) keys.push(t.keys)
        else keys[slot] = t.keys
        keys = keys.filter((k, i) => keys.findIndex(o => Keymap.canon(o) === Keymap.canon(k)) === i)

        const shown = Keymap.label(t.keys)
        const go = () => apply(r, keys, t.keys)
        // a plain key on the desktop would stop it from typing anywhere
        const s = Keymap.split(t.keys)
        if (!r.app && !s.mods.length && !/^F\d+$/.test(s.key)) {
            ask = { text: shown + " alone would stop typing " + shown + " everywhere", yes: "use it anyway", go: go }
            return
        }
        const others = Keymap.clashes(r, [t.keys])
        if (others.length) {
            ask = { text: shown + " is already " + others.map(o => "“" + o.label + "”").join(", "), yes: "take it over", go: go }
            return
        }
        go()
    }
    // the new keys; the same keys come off other actions in the layer (a whole {n} key, if one
    // of its desktops clashes)
    function apply(r, keys, added) {
        const changes = {}
        changes[r.action] = keys
        const mine = Keymap.expand([added])
        for (const o of Keymap.clashes(r, [added]))
            changes[o.action] = o.keys.filter(k => !Keymap.expand([k]).some(e => mine.includes(e)))
        Keymap.save(changes)
    }

    // ---- what the window's keys do here (tty/keys.json's settings.* actions) ---------------
    function next() { if (current < shown.length - 1) current++ }
    function prev() { if (current > 0) current-- }
    function activate() {
        if (ask) { const a = ask; ask = null; a.go(); return }
        if (row) record(row, slotFor(row))
    }
    function addKey() { if (row) record(row, -1) }
    function unbind() {
        if (row && !row.fixed && row.keys.length) { const c = {}; c[row.action] = []; Keymap.save(c) }
    }
    function back() { if (ask) { ask = null; return true } return false }
    function lower() {}
    function higher() {}
    function undo() { if (!Keymap.undo()) say("nothing to undo") }
    function redo() { if (!Keymap.redo()) say("nothing to redo") }

    // ---- drawing --------------------------------------------------------------------------
    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            Repeater {
                id: list
                model: page.items
                delegate: Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: modelData.heading !== undefined ? heading : line
                    property var item: modelData
                }
            }
        }
    }
    // keep the picked row in sight when the keys move it
    onCurrentChanged: if (!mouseLive) Qt.callLater(show)
    function show() {
        const i = items.findIndex(it => it.index === current)
        const it = list.itemAt(i)
        if (!it) return
        if (it.y < flick.contentY + 30) flick.contentY = Math.max(0, it.y - 30 - (i === 1 ? 30 : 0))
        else if (it.y + it.height > flick.contentY + flick.height - 20) flick.contentY = it.y + it.height - flick.height + 20
    }

    Text {
        anchors.centerIn: parent
        visible: page.shown.length === 0
        text: Keymap.rows.length ? "nothing fits “" + page.query + "”" : "can't read tty/keys.json"
        font: Style.font
        color: Style.dim
    }

    Component {
        id: heading
        Item {
            height: 48
            Text {
                anchors { left: parent.left; leftMargin: Style.pad; bottom: parent.bottom; bottomMargin: 8 }
                text: (parent.parent.item.heading ?? "").toUpperCase()
                font: Style.heading
                color: Style.accent
            }
        }
    }

    Component {
        id: line
        Rectangle {
            id: rowItem
            readonly property var r: parent.item.row
            readonly property int index: parent.item.index
            readonly property bool picked: index === page.current
            readonly property bool recordingHere: !!page.rec && page.rec.action === r.action
            height: Style.row
            color: picked ? Style.raised : "transparent"
            Behavior on color { ColorAnimation { duration: Style.quick } }

            Rectangle {   // the pick's mark
                width: 3; height: parent.height
                color: Style.accent
                opacity: rowItem.picked ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Style.quick } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: if (page.mouseLive) page.current = rowItem.index
                onPositionChanged: page.current = rowItem.index
                onClicked: page.current = rowItem.index
                onDoubleClicked: page.record(rowItem.r, page.slotFor(rowItem.r))
            }

            RowLayout {
                anchors { fill: parent; leftMargin: Style.pad; rightMargin: Style.pad }
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: rowItem.r.label
                    elide: Text.ElideRight
                    font: Style.font
                    color: rowItem.r.fixed ? Style.dim : rowItem.picked ? Style.strong : Style.text
                }
                Text {   // the action's name, for the picked row (what tty/keys.json calls it)
                    visible: rowItem.picked && !rowItem.r.fixed && rowItem.width > 700
                    text: rowItem.r.action ?? ""
                    font: Style.small
                    color: Style.faint
                }
                // notes (mouse binds, ...): shown, not changed here
                Text {
                    visible: !!rowItem.r.fixed
                    text: (rowItem.r.keysLabel ?? []).join("   ")
                    font: Style.font
                    color: Style.dim
                }
                KeyChip {   // one more key: on the picked row, left of its keys (a row without keys: its first)
                    visible: !rowItem.r.fixed && !rowItem.recordingHere && (rowItem.picked || rowItem.r.keys.length === 0)
                    add: true
                    rowActive: rowItem.picked
                    opacity: rowItem.picked ? 1 : 0
                    onClicked: { page.current = rowItem.index; page.record(rowItem.r, -1) }
                }
                Text {   // no keys
                    visible: !rowItem.r.fixed && rowItem.r.keys.length === 0 && !rowItem.recordingHere && !rowItem.picked
                    Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignHCenter
                    text: "–"
                    font: Style.font
                    color: Style.faint
                }
                Repeater {
                    model: rowItem.r.fixed || (rowItem.recordingHere && page.rec.slot === -2) ? [] : rowItem.r.keys
                    delegate: KeyChip {
                        required property string modelData
                        required property int index
                        text: Keymap.label(modelData)
                        recording: rowItem.recordingHere && page.rec.slot === index
                        onClicked: { page.current = rowItem.index; page.record(rowItem.r, index) }
                    }
                }
                KeyChip {   // the new key being recorded (one more, or instead of all)
                    visible: rowItem.recordingHere && page.rec.slot < 0
                    recording: true
                }
            }
        }
    }
}

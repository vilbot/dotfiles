// Every desktop action from keys/remap.toml (services/Keymap.qml) with its keys.
// Keys are typed as in remap.toml: cmd / opt / ctrl / shift + one key ("opt+shift+f"), several
// separated by commas, empty = none. Apply (or Enter) saves through `mackeys set`.
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    id: page
    spacing: 0

    property var draft: ({})     // action -> "text", only rows being changed
    readonly property int changes: Object.keys(draft).length

    // text shown in a field: what's typed, or what remap.toml has
    function saved(row) { return row.keys.join(", ") }
    function shown(row) { return draft[row.action] ?? saved(row) }
    function edit(row, text) {
        const next = Object.assign({}, draft)
        if (text.trim() === saved(row)) delete next[row.action]
        else next[row.action] = text
        draft = next
    }
    function keys(text) { return text.split(",").map(k => k.trim().toLowerCase()).filter(k => k) }
    // rough shape only; mackeys checks the real thing and says what's wrong
    function looksOk(text) {
        return keys(text).every(k => /^((l|r)?(cmd|opt|ctrl|shift)\+)*(.|[a-z0-9]+|\{n\}|\{dir\})$/.test(k.replace(/\s/g, "")))
    }
    function apply() {
        if (!changes || Keymap.busy) return
        const out = {}
        for (const action in draft) out[action] = keys(draft[action])
        Keymap.apply(out)
    }
    Connections {
        target: Keymap
        function onApplied() { page.draft = {} }
    }

    // ---- top: how to type keys, apply / undo, result ----
    Text {
        Layout.fillWidth: true
        text: "Type keys as cmd, opt, ctrl or shift + a key, e.g. opt+shift+f; several keys: separate with commas. "
            + "{n} is the desktop number 1–" + Keymap.desktops + ", {dir} is h j k l. "
            + "f1–f12 are the F-row keys, which act like a Mac's (right Option + F-key gives the plain F-key)."
        wrapMode: Text.Wrap
        color: Theme.inkDim
        font: Theme.textSmall
        Layout.bottomMargin: 12
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 18
        spacing: 18
        LinkText {
            text: Keymap.busy ? "applying…" : page.changes ? "apply " + page.changes + (page.changes === 1 ? " change" : " changes") : "apply"
            active: page.changes > 0 && !Keymap.busy
            onClicked: page.apply()
        }
        LinkText {
            text: "undo"
            active: page.changes > 0 && !Keymap.busy
            opacity: page.changes ? 1 : 0
            onClicked: { page.draft = {}; Keymap.error = "" }
        }
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Keymap.error
            color: Keymap.error ? Theme.urgent : Theme.inkFaint
            font: Theme.textSmall
        }
    }

    // ---- sections ----
    Repeater {
        model: Keymap.groups
        delegate: ColumnLayout {
            id: group
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.topMargin: index ? 22 : 0
            spacing: 6

            Heading { text: group.modelData.title.toUpperCase(); color: Theme.inkDim; Layout.bottomMargin: 2 }

            Repeater {
                model: group.modelData.rows
                delegate: RowLayout {
                    id: row
                    required property var modelData
                    readonly property var r: modelData
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        Layout.fillWidth: true
                        text: row.r.label
                        elide: Text.ElideRight
                        color: row.r.fixed ? Theme.inkDim : Theme.ink
                        font: Theme.text
                    }
                    // notes (mouse binds, ...): shown, not editable
                    Text {
                        visible: !!row.r.fixed
                        Layout.preferredWidth: 200
                        text: (row.r.keysLabel ?? []).join(", ")
                        color: Theme.inkFaint
                        font: Theme.textItalic
                    }
                    TextBox {
                        visible: !row.r.fixed
                        Layout.preferredWidth: 200
                        implicitHeight: 24
                        text: row.r.fixed ? "" : page.shown(row.r)
                        changed: !row.r.fixed && page.draft[row.r.action] !== undefined
                        invalid: !page.looksOk(text)
                        placeholder: "–"
                        onEdited: t => page.edit(row.r, t)
                        onAccepted: page.apply()
                    }
                }
            }
        }
    }

}

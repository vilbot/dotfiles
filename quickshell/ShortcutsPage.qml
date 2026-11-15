// Settings window page: every desktop action from keys/remap.toml (through Keymap.qml) with its keys.
// Keys are typed as in remap.toml: cmd / opt / ctrl / shift + one key ("opt+shift+f"), several
// separated by commas, empty = none. Apply (or Enter) saves through `mackeys set`.
import QtQuick
import QtQuick.Layouts

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

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Text { Layout.fillWidth: true; text: group.modelData.title.toUpperCase(); color: Theme.inkDim; font: Theme.textCaps }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline; Layout.bottomMargin: 2 }

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
                    KeyField {
                        visible: !row.r.fixed
                        Layout.preferredWidth: 200
                        text: row.r.fixed ? "" : page.shown(row.r)
                        changed: !row.r.fixed && page.draft[row.r.action] !== undefined
                        ok: page.looksOk(text)
                        placeholder: "–"
                        onEdited: t => page.edit(row.r, t)
                        onSubmit: page.apply()
                    }
                }
            }
        }
    }

    // a key text box: thin frame, darker while typing, red-ish when the keys don't look right
    component KeyField: Rectangle {
        id: kf
        property alias text: input.text
        property bool changed: false
        property bool ok: true
        property string placeholder: ""
        signal edited(string text)
        signal submit()
        Layout.preferredWidth: 160
        implicitHeight: 24
        color: kf.changed ? Theme.hover : "transparent"
        radius: 2
        border {
            width: 1
            color: !kf.ok ? Theme.urgent : input.activeFocus ? Theme.inkDim : Theme.hairline
        }
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 7; rightMargin: 7 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Theme.ink
            selectByMouse: true
            font: Qt.font({ family: Theme.fontFamily, pixelSize: Theme.fontSize - 1 })
            onTextEdited: kf.edited(text)
            onAccepted: kf.submit()
        }
        Text {
            anchors { fill: input }
            verticalAlignment: Text.AlignVCenter
            visible: !input.text && !input.activeFocus
            text: kf.placeholder
            color: Theme.inkFaint
            font: Theme.textItalic
        }
    }
}

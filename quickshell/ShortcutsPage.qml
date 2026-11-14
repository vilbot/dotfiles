// Settings window page: every keyboard shortcut from keys/keymap.toml (through Keymap.qml),
// with its Hyprland key and its KDE key side by side.
// Keys are typed as in keymap.toml: cmd / opt / ctrl / shift + one key ("opt+shift+f"), several
// separated by commas. KDE empty = the same key as Hyprland; "none" = off on KDE only;
// "–" = KDE has no such action. Apply (or Enter) saves and runs keys/build.py --apply.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page
    spacing: 0

    property var draft: ({})     // action -> { hypr: "text", kde: "text" }, only rows being changed
    readonly property int changes: Object.keys(draft).length

    // text shown in a field: what's typed, or what keymap.toml has
    function saved(row, side) {
        if (side === "hypr") return row.hypr.join(", ")
        return row.kde === null ? "" : row.kde.length ? row.kde.join(", ") : "none"
    }
    function shown(row, side) {
        const d = draft[row.action]
        return d && d[side] !== undefined ? d[side] : saved(row, side)
    }
    function edit(row, side, text) {
        const next = Object.assign({}, draft)
        const d = Object.assign({}, next[row.action] ?? {})
        d[side] = text
        if (["hypr", "kde"].every(s => (d[s] ?? saved(row, s)).trim() === saved(row, s))) delete next[row.action]
        else next[row.action] = d
        draft = next
    }
    function keys(text) { return text.split(",").map(k => k.trim().toLowerCase()).filter(k => k) }
    // rough shape only; keys/build.py checks the real thing and says what's wrong
    function looksOk(text, allowNone) {
        if (allowNone && text.trim().toLowerCase() === "none") return true
        return keys(text).every(k => /^((cmd|opt|ctrl|shift)\+)*([a-z0-9]+|\{n\}|\{dir\})$/.test(k.replace(/\s/g, "")))
    }
    function apply() {
        if (!changes || Keymap.busy) return
        const out = {}
        for (const g of Keymap.groups) for (const row of g.rows) {
            if (!row.action || !draft[row.action]) continue
            const kde = shown(row, "kde").trim().toLowerCase()
            out[row.action] = { hypr: keys(shown(row, "hypr")), kde: kde === "" ? null : kde === "none" ? [] : keys(kde) }
        }
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
            + "KDE left empty uses the Hyprland key, none turns it off on KDE only, – means KDE has no such action. "
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
            text: Keymap.error ? Keymap.error
                : Keymap.kdeChanged ? "Saved. KDE uses the new keys after logging out and in there." : ""
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
                Text { Layout.preferredWidth: 160; text: "HYPRLAND"; color: Theme.inkFaint; font: Theme.textCaps; visible: group.index === 0 }
                Text { Layout.preferredWidth: 160; text: "KDE"; color: Theme.inkFaint; font: Theme.textCaps; visible: group.index === 0 }
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
                    // mouse binds from hyprland.lua: shown, not editable
                    Text {
                        visible: !!row.r.fixed
                        Layout.preferredWidth: 160
                        text: (row.r.hyprLabel ?? []).join(", ")
                        color: Theme.inkFaint
                        font: Theme.textItalic
                    }
                    KeyField {
                        visible: !row.r.fixed
                        text: row.r.fixed ? "" : page.shown(row.r, "hypr")
                        changed: !row.r.fixed && page.draft[row.r.action]?.hypr !== undefined
                        ok: page.looksOk(text, false)
                        placeholder: "–"
                        onEdited: t => page.edit(row.r, "hypr", t)
                        onSubmit: page.apply()
                    }
                    KeyField {
                        visible: !row.r.fixed && row.r.hasKde
                        text: row.r.fixed ? "" : page.shown(row.r, "kde")
                        changed: !row.r.fixed && page.draft[row.r.action]?.kde !== undefined
                        ok: page.looksOk(text, true)
                        placeholder: "same"
                        onEdited: t => page.edit(row.r, "kde", t)
                        onSubmit: page.apply()
                    }
                    Text {
                        visible: !!row.r.fixed || !row.r.hasKde
                        Layout.preferredWidth: 160
                        text: "–"
                        color: Theme.inkFaint
                        font: Theme.text
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

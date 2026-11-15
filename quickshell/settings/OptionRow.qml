// One Hyprland option: label and description, then a switch, slider, choices or color field,
// whichever fits its kind. "default" drops the saved value.
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    id: row
    property var opt: ({})
    readonly property var m: HyprSettings.meta[opt.key] ?? {}
    readonly property string kind: HyprSettings.kinds[opt.key] ?? ""
    readonly property var value: HyprSettings.values[opt.key]
    readonly property bool overridden: HyprSettings.overridden(opt.key)
    // choices: given, or Hyprland's map ([{name: value}, ...]) sorted by value
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

    function set(v) { HyprSettings.set(opt, v) }

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
            onToggled: v => row.set(v)
        }
        Slider {
            id: slider
            visible: row.type === "number"
            Layout.fillWidth: true
            value: ((row.value ?? 0) - row.lo) / (row.hi - row.lo)
            onMoved: v => row.set(Math.round(Math.round((row.lo + v * (row.hi - row.lo)) / row.step) * row.step * 10000) / 10000)
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
        Choices {
            visible: row.type === "choice"
            spacing: 16
            choices: row.choices ?? []
            isSelected: v => row.value === v
            onPicked: v => row.set(v)
        }
        // color: swatch + RRGGBBAA, Enter applies
        Row {
            visible: row.type === "color"
            spacing: 10
            Rectangle {
                width: 22; height: 22; radius: 2
                border { color: Theme.hairline; width: 1 }
                color: row.type === "color" && row.value ? "#" + row.value.slice(6, 8) + row.value.slice(0, 6) : "transparent"   // Qt: #AARRGGBB
            }
            TextBox {
                width: 96; height: 22
                text: row.type === "color" ? (row.value ?? "") : ""
                maximumLength: 8
                font: Theme.textCaps
                validator: RegularExpressionValidator { regularExpression: /[0-9a-fA-F]{0,8}/ }
                onAccepted: t => {
                    t = t.toLowerCase()
                    if (t.length === 6) row.set(t + "ff")
                    else if (t.length === 8) row.set(t)
                }
            }
        }
        Item { Layout.fillWidth: row.type !== "number" && row.type !== "choice" }
        LinkText {
            text: "default"
            active: row.overridden
            opacity: row.overridden ? 1 : 0
            onClicked: HyprSettings.reset(row.opt)
        }
    }
    Divider {}
}

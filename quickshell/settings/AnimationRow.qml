// One leaf of Hyprland's animation tree: on/off, duration, curve, style.
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets
import "schema.js" as Schema

ColumnLayout {
    id: ab
    property var info
    readonly property var a: HyprSettings.anim(info.leaf)
    readonly property bool overridden: HyprSettings.animOverridden(info.leaf)
    readonly property bool inherited: info.parent !== null && !(HyprSettings.anims[info.leaf]?.overridden)
    function set(changes) { HyprSettings.setAnim(info.leaf, changes) }
    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 18
        spacing: 16
        Text { text: ab.info.label; color: Theme.ink; font: Theme.strong }
        Text {
            visible: ab.inherited
            text: "same as " + (Schema.animLeaves.find(l => l.leaf === ab.info.parent)?.label ?? "").toLowerCase()
            color: Theme.inkFaint
            font: Theme.textSmall
        }
        Item { Layout.fillWidth: true }
        LinkText {
            text: "default"
            active: ab.overridden
            opacity: ab.overridden ? 1 : 0
            onClicked: HyprSettings.resetAnim(ab.info.leaf)
        }
        Toggle { checked: ab.a.enabled; onToggled: v => ab.set({ enabled: v }) }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 16
        Text { text: "Duration"; color: Theme.inkDim; font: Theme.textItalic; Layout.preferredWidth: 90 }
        Slider {     // speed is in tenths of a second, 0.5 .. 20
            Layout.fillWidth: true
            value: (ab.a.speed - 0.5) / 19.5
            onMoved: v => ab.set({ speed: Math.round((0.5 + v * 19.5) * 10) / 10 })
        }
        Text {
            Layout.preferredWidth: 64
            horizontalAlignment: Text.AlignRight
            text: (ab.a.speed / 10).toFixed(2) + " s"
            color: Theme.inkDim
            font: Theme.text
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 16
        Text { text: "Curve"; color: Theme.inkDim; font: Theme.textItalic; Layout.preferredWidth: 90; Layout.alignment: Qt.AlignTop }
        Choices {
            choices: HyprSettings.curves.map(c => [c.name, c.label])
            isSelected: v => (ab.a.curve || "default") === v
            onPicked: v => ab.set({ curve: v })
        }
    }
    RowLayout {
        visible: ab.info.styles !== undefined
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 16
        Text { text: "Style"; color: Theme.inkDim; font: Theme.textItalic; Layout.preferredWidth: 90; Layout.alignment: Qt.AlignTop }
        Choices {
            choices: ab.info.styles ?? []
            isSelected: v => (ab.a.style ?? "") === v
            onPicked: v => ab.set({ style: v })
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.topMargin: 14; implicitHeight: 1; color: Theme.hairline }

}

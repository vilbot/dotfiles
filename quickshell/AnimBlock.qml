// Settings window, Animations page: one leaf of Hyprland's animation tree (on/off, duration,
// curve, style). Lives in its own file because QML refused it as an inline component there.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: ab
    property var info
    required property var settings    // Settings.qml's root
    readonly property var a: settings.anim(info.leaf)
    readonly property bool overridden: settings.animOverrides[info.leaf] !== undefined
    readonly property bool inherited: info.parent !== null && !(settings.anims[info.leaf] && settings.anims[info.leaf].overridden)
    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 18
        spacing: 16
        Text { text: ab.info.label; color: Theme.ink; font: Qt.font({ family: Theme.fontFamily, pixelSize: Theme.fontSize + 1, bold: true }) }
        Text {
            visible: ab.inherited
            text: "same as " + (settings.animLeaves.find(l => l.leaf === ab.info.parent)?.label ?? "").toLowerCase()
            color: Theme.inkFaint
            font: Theme.textSmall
        }
        Item { Layout.fillWidth: true }
        LinkText {
            text: "default"
            active: ab.overridden
            opacity: ab.overridden ? 1 : 0
            onClicked: settings.resetAnim(ab.info.leaf)
        }
        Toggle { checked: ab.a.enabled; onToggled: v => settings.setAnim(ab.info.leaf, { enabled: v }) }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 16
        Text { text: "Duration"; color: Theme.inkDim; font: Theme.textItalic; Layout.preferredWidth: 90 }
        Slider {     // speed is in tenths of a second, 0.5 .. 20
            Layout.fillWidth: true
            value: (ab.a.speed - 0.5) / 19.5
            onMoved: v => settings.setAnim(ab.info.leaf, { speed: Math.round((0.5 + v * 19.5) * 10) / 10 })
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
        Flow {
            Layout.fillWidth: true
            spacing: 14
            Repeater {
                model: settings.curves
                delegate: AnimChoice {
                    required property var modelData
                    text: modelData[1]
                    selected: (ab.a.curve || "default") === modelData[0]
                    onClicked: settings.setAnim(ab.info.leaf, { curve: modelData[0] })
                }
            }
        }
    }
    RowLayout {
        visible: ab.info.styles !== undefined
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 16
        Text { text: "Style"; color: Theme.inkDim; font: Theme.textItalic; Layout.preferredWidth: 90; Layout.alignment: Qt.AlignTop }
        Flow {
            Layout.fillWidth: true
            spacing: 14
            Repeater {
                model: ab.info.styles ?? []
                delegate: AnimChoice {
                    required property var modelData
                    text: modelData[1]
                    selected: (ab.a.style ?? "") === modelData[0]
                    onClicked: settings.setAnim(ab.info.leaf, { style: modelData[0] })
                }
            }
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.topMargin: 14; implicitHeight: 1; color: Theme.hairline }

    // italic word; selected = upright ink with an underline (same look as Settings.qml's Choice)
    component AnimChoice: Text {
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
}

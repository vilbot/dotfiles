// Output volume and device, input volume and device.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

ColumnLayout {
    id: root
    spacing: 8

    Text { text: "SOUND"; color: Theme.inkFaint; font: Theme.textCaps }

    VolumeRow { node: Audio.sink }
    Devices { nodes: Audio.sinks; current: Audio.sink }
    VolumeRow { node: Audio.source; visible: Audio.source !== null; Layout.topMargin: 4 }
    Devices { nodes: Audio.sources; current: Audio.source }

    component VolumeRow: RowLayout {
        id: vr
        property var node
        Layout.fillWidth: true
        spacing: 10
        SymbolIcon {
            implicitSize: 16
            source: Quickshell.iconPath(Audio.icon(vr.node))
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Audio.toggleMute(vr.node) }
        }
        Slider {
            Layout.fillWidth: true
            enabled: !!vr.node?.audio && !Audio.muted(vr.node)
            value: Audio.volume(vr.node)
            onMoved: v => Audio.setVolume(vr.node, v)
        }
        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round(Audio.volume(vr.node) * 100) + "%"
            color: Theme.inkDim
            font: Theme.text
        }
    }

    // the devices to switch to, when there's more than one: "• Current", others in italic
    component Devices: ColumnLayout {
        id: dv
        property var nodes: []
        property var current
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: dv.nodes.length > 1 ? dv.nodes : []
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool isCurrent: modelData === dv.current
                Layout.fillWidth: true
                implicitHeight: t.implicitHeight + 2
                Text {
                    id: t
                    anchors { left: parent.left; right: parent.right; leftMargin: 26 }
                    text: (row.isCurrent ? "• " : "") + Audio.label(row.modelData)
                    elide: Text.ElideRight
                    color: row.isCurrent || a.containsMouse ? Theme.ink : Theme.inkDim
                    font: row.isCurrent ? Theme.text : Theme.textItalic
                }
                MouseArea {
                    id: a
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.makeDefault(row.modelData)
                }
            }
        }
    }
}

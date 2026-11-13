// Control center: output volume + device, input volume + device.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root
    spacing: 8

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var hardware: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var sinks: hardware.filter(n => n.isSink)
    readonly property var sources: hardware.filter(n => !n.isSink)

    PwObjectTracker { objects: [root.sink, root.source] }

    function label(n) { return n.description || n.nickname || n.name }

    Text { text: "SOUND"; color: Theme.inkFaint; font: Theme.textCaps }

    // output
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        IconImage {
            implicitSize: 16
            source: Quickshell.iconPath(root.sink?.audio?.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
        }
        Slider {
            Layout.fillWidth: true
            enabled: root.sink?.audio && !root.sink.audio.muted
            value: root.sink?.audio?.volume ?? 0
            onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v }
        }
        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
            color: Theme.inkDim
            font: Theme.text
        }
    }
    Repeater {
        model: root.sinks.length > 1 ? root.sinks : []
        delegate: DeviceRow {
            required property var modelData
            text: root.label(modelData)
            current: modelData === root.sink
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    // input
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: root.source !== null
        spacing: 10
        IconImage {
            implicitSize: 16
            source: Quickshell.iconPath(root.source?.audio?.muted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic")
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
            }
        }
        Slider {
            Layout.fillWidth: true
            enabled: root.source?.audio && !root.source.audio.muted
            value: root.source?.audio?.volume ?? 0
            onMoved: v => { if (root.source?.audio) root.source.audio.volume = v }
        }
        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round((root.source?.audio?.volume ?? 0) * 100) + "%"
            color: Theme.inkDim
            font: Theme.text
        }
    }
    Repeater {
        model: root.sources.length > 1 ? root.sources : []
        delegate: DeviceRow {
            required property var modelData
            text: root.label(modelData)
            current: modelData === root.source
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }

    // one selectable device: "• Name" (current) or plain italic
    component DeviceRow: Item {
        id: row
        property string text
        property bool current
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: t.implicitHeight + 2
        Text {
            id: t
            anchors { left: parent.left; right: parent.right; leftMargin: 26 }
            text: (row.current ? "• " : "") + row.text
            elide: Text.ElideRight
            color: row.current || a.containsMouse ? Theme.ink : Theme.inkDim
            font: row.current ? Theme.text : Theme.textItalic
        }
        MouseArea {
            id: a
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}

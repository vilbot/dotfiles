// Default output volume. Click to mute, scroll to change.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Item {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: sink !== null

    // Pipewire objects only report live values while tracked.
    PwObjectTracker { objects: [root.sink] }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        IconImage {
            implicitSize: 16
            source: Quickshell.iconPath(root.muted || root.volume === 0 ? "audio-volume-muted-symbolic"
                                      : root.volume < 0.34 ? "audio-volume-low-symbolic"
                                      : root.volume < 0.67 ? "audio-volume-medium-symbolic"
                                      : "audio-volume-high-symbolic")
        }
        Text {
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.inkFaint : Theme.inkDim
            font: Theme.text
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
        onWheel: wheel => {
            if (!root.sink?.audio) return
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0, Math.min(1, root.volume + step))
        }
    }
}

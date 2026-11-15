// Output volume. Click to mute, scroll to change.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: Audio.sink !== null

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5
        SymbolIcon { implicitSize: 16; source: Quickshell.iconPath(Audio.icon(Audio.sink)) }
        Text {
            text: Math.round(Audio.volume(Audio.sink) * 100) + "%"
            color: Audio.muted(Audio.sink) ? Theme.inkFaint : Theme.inkDim
            font: Theme.text
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Audio.toggleMute(Audio.sink)
        onWheel: wheel => Audio.setVolume(Audio.sink, Audio.volume(Audio.sink) + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}

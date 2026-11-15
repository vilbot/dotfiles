// Thin ink slider: hairline track, filled part in ink, small round handle.
// `value` is 0..1 and stays bound to whatever you give it; while dragging, the slider shows the
// drag position and emits moved(v). released(v) fires when the mouse lets go.
import QtQuick
import qs.services

Item {
    id: s
    property real value: 0
    property bool enabled: true
    signal moved(real value)
    signal released(real value)

    readonly property real shown: area.pressed ? dragValue : Math.max(0, Math.min(1, value))
    property real dragValue: 0

    implicitWidth: 200
    implicitHeight: 20
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 2
        color: Theme.hairline
    }
    Rectangle {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: s.shown * s.width
        height: 2
        color: Theme.ink
    }
    Rectangle {
        x: s.shown * (s.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 12; height: 12; radius: 6
        color: Theme.paper
        border { color: Theme.ink; width: 1 }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: s.enabled
        cursorShape: Qt.PointingHandCursor
        function at(x) { return Math.max(0, Math.min(1, x / s.width)) }
        onPressed: mouse => { s.dragValue = at(mouse.x); s.moved(s.dragValue) }
        onPositionChanged: mouse => { if (pressed) { s.dragValue = at(mouse.x); s.moved(s.dragValue) } }
        onReleased: s.released(s.dragValue)
        onWheel: wheel => {
            const v = Math.max(0, Math.min(1, s.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
            s.moved(v); s.released(v)
        }
    }
}

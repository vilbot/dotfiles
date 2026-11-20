// A slider: drag the handle or click the track, the wheel moves it a step. The value shows on
// the right. `moved(value)` while it changes.
import QtQuick

Item {
    id: slider
    property real from: 0
    property real to: 1
    property real step: 0.01
    property real value: 0
    property bool active: false          // its row is picked: the handle lights up
    property string unit: ""
    property string zero: ""             // what 0 says ("never")
    property int decimals: step >= 1 ? 0 : step >= 0.1 ? 1 : 2
    signal moved(real value)

    implicitWidth: 320
    implicitHeight: 24
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property bool hot: area.containsMouse || area.pressed || active

    function snap(v) {
        const n = Math.round((v - from) / step) * step + from
        return +Math.max(from, Math.min(to, n)).toFixed(6)
    }
    function nudge(steps) { const v = snap(value + steps * step); if (v !== value) moved(v) }

    Item {
        id: track
        anchors { left: parent.left; right: readout.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        height: 16
        Rectangle {   // the track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 2
            color: Style.line
        }
        Rectangle {   // filled up to the value
            anchors.verticalCenter: parent.verticalCenter
            width: slider.frac * parent.width; height: 2
            color: slider.hot ? Style.accent : Style.dim
            Behavior on color { ColorAnimation { duration: Style.quick } }
        }
        Rectangle {   // the handle
            x: slider.frac * (parent.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: area.pressed ? 6 : 4
            height: 16
            color: slider.hot ? Style.accent : Style.text
            Behavior on width { NumberAnimation { duration: Style.quick } }
            Behavior on color { ColorAnimation { duration: Style.quick } }
        }
        MouseArea {
            id: area
            anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            function at(x) { return slider.snap(slider.from + Math.max(0, Math.min(1, x / track.width)) * (slider.to - slider.from)) }
            onPressed: mouse => { const v = at(mouse.x); if (v !== slider.value) slider.moved(v) }
            onPositionChanged: mouse => { if (pressed) { const v = at(mouse.x); if (v !== slider.value) slider.moved(v) } }
            onWheel: wheel => slider.nudge(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }
    Text {
        id: readout
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 80
        horizontalAlignment: Text.AlignRight
        text: slider.zero && slider.value === 0 ? slider.zero : slider.value.toFixed(slider.decimals) + slider.unit
        font: Style.font
        color: slider.hot ? Style.strong : Style.text
    }
}

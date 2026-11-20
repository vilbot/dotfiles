// One key on the Shortcuts page: "⌥ ⇧ 1–5" in a box. Hover lights it, a click records new keys
// for it. While recording it waits, blinking; `add` is the "+" box that records one more key.
import QtQuick

Rectangle {
    id: chip
    property string text: ""
    property bool recording: false
    property bool add: false
    property bool rowActive: false        // its row is the picked one
    signal clicked()

    readonly property bool hot: area.containsMouse || recording
    implicitWidth: Math.max(label.implicitWidth + 18, 30)
    implicitHeight: 24
    color: recording ? Qt.alpha(Style.accent, 0.12) : hot ? Style.line : "transparent"
    border.width: 1
    border.color: recording || area.containsMouse ? Style.accent : add ? (rowActive ? Style.faint : "transparent") : Style.faint
    Behavior on color { ColorAnimation { duration: Style.quick } }

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.recording ? "press keys" + (blink.on ? "▌" : " ") : chip.add ? "+" : chip.text
        font: Style.font
        color: chip.recording ? Style.accent : chip.add ? (chip.hot ? Style.accent : Style.dim) : Style.strong
    }
    Timer {
        id: blink
        property bool on: true
        running: chip.recording
        repeat: true
        interval: 500
        onTriggered: on = !on
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}

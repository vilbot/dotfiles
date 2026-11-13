// Bar button for the control center: two small switches drawn in ink (like the Mac's icon).
import QtQuick

Item {
    id: root
    implicitWidth: 16
    implicitHeight: 14
    readonly property color ink: Panels.controlOpen || area.containsMouse ? Theme.ink : Theme.inkDim

    // top switch: knob right (on); bottom switch: knob left (off)
    Repeater {
        model: [{ y: 0, on: true }, { y: 8, on: false }]
        Rectangle {
            required property var modelData
            y: modelData.y
            width: 16; height: 6; radius: 3
            color: "transparent"
            border { color: root.ink; width: 1 }
            Rectangle {
                width: 4; height: 4; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                x: parent.modelData.on ? parent.width - width - 1 : 1
                color: root.ink
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggleControl()
    }
}

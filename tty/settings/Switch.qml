// On / off: a sliding knob. Click it (or its row), Enter on its row.
import QtQuick

Item {
    id: sw
    property bool checked: false
    property bool active: false
    signal toggled(bool checked)
    implicitWidth: 40
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        color: sw.checked ? Qt.alpha(Style.accent, 0.25) : "transparent"
        border.width: 1
        border.color: sw.checked || sw.active || area.containsMouse ? Style.accent : Style.faint
        Behavior on color { ColorAnimation { duration: Style.quick } }
        Rectangle {
            width: 14; height: 14
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Style.accent : Style.dim
            Behavior on x { NumberAnimation { duration: Style.quick; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Style.quick } }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}

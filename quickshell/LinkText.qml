// Italic text that acts like a link: darker and underlined on hover.
import QtQuick

Text {
    id: l
    signal clicked()
    property bool active: true          // false: shown faint, not clickable
    color: !active ? Theme.inkFaint : area.containsMouse ? Theme.ink : Theme.inkDim
    font: Theme.textItalic

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.bottom }
        height: 1
        color: Theme.ink
        visible: area.containsMouse && l.active
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3
        enabled: l.active
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: l.clicked()
    }
}

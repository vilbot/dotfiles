// One of a few choices, as an italic word; the chosen one is upright with an underline.
import QtQuick
import qs.services

Text {
    id: ch
    property bool selected
    signal clicked()
    color: selected || area.containsMouse ? Theme.ink : Theme.inkDim
    font: selected ? Theme.text : Theme.textItalic
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 1 }
        height: 1; color: Theme.ink; visible: ch.selected
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ch.clicked()
    }
}

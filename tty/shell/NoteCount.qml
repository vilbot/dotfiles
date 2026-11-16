// "[n]" in the bar, left of the settings button: how many notifications are in the list. Hidden
// when there are none, except while not disturbing ("dnd"), so the list (and its switch) can
// still be opened. Click: the list (Corner.qml).
import QtQuick

Text {
    readonly property int count: Notes.list.length
    visible: count > 0 || Notes.dnd
    text: Notes.dnd ? "dnd" + (count > 0 ? " " + count : "") : "[" + count + "]"
    font: Notes.dnd ? Ui.font : Ui.bold
    color: Notes.dnd ? Colors.base04 : Colors.base0E
    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Notes.listOpen = !Notes.listOpen }
}

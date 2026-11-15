// One box of text in the corner, drawn like a terminal: square, 1px border, Hack.
import QtQuick

Rectangle {
    id: line
    property string title: ""         // bold first line (notifications)
    property string text: ""
    property color ink: Colors.base06
    signal clicked()

    anchors.right: parent?.right
    width: Math.min(parent?.width ?? 460, words.implicitWidth + 24)
    height: words.implicitHeight + 12
    color: Colors.base00
    border { color: Colors.base03; width: 1 }

    Text {
        id: words
        x: 12; y: 6
        width: Math.min(implicitWidth, (line.parent?.width ?? 460) - 24)
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: 6
        elide: Text.ElideRight
        font { family: "Hack"; pixelSize: 15 }
        color: line.ink
        text: (line.title ? "<b>" + esc(line.title) + "</b>" + (line.text ? "<br>" : "") : "")
              + esc(line.text).replace(/\n/g, "<br>")
        function esc(s) { return (s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;") }
    }
    MouseArea { anchors.fill: parent; onClicked: line.clicked() }
}

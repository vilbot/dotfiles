// One box of text, drawn like a terminal: square, 1px border, Hack. It comes and goes like the
// launcher (fade with a small slide) when `shown` changes; clicking it flashes it (so you see the
// click land) and then sends clicked().
import QtQuick

Rectangle {
    id: line
    property string title: ""         // bold first line (notifications)
    property string text: ""
    property color ink: Colors.base06
    property int maxWidth: parent?.width ?? 460
    property bool shown: true
    property var buttons: []          // notification actions: [{ text }]; a click sends pressed(i)
    signal clicked()
    signal pressed(int index)

    width: Math.min(maxWidth, Math.max(words.implicitWidth, buttons.length ? buttonRow.width : 0) + 24)
    height: words.implicitHeight + 12 + (buttons.length ? buttonRow.height + 4 : 0)
    color: flash.running ? Colors.base0D : mouse.containsMouse ? Colors.base01 : Colors.base00
    border { color: Colors.base03; width: 1 }
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Ui.quick } }
    transform: Translate { y: -6 * (1 - line.opacity) }
    Behavior on color { enabled: !flash.running; ColorAnimation { duration: Ui.quick } }

    Text {
        id: words
        x: 12; y: 6
        width: Math.min(implicitWidth, line.maxWidth - 24)
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: 6
        elide: Text.ElideRight
        font: Ui.font
        color: flash.running ? Colors.base00 : line.ink
        text: (line.title ? "<b>" + esc(line.title) + "</b>" + (line.text ? "<br>" : "") : "")
              + esc(line.text).replace(/\n/g, "<br>")
        function esc(s) { return (s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;") }
    }
    Row {   // the buttons, as text: [Run Cachy-Update]  [Close]
        id: buttonRow
        visible: line.buttons.length > 0
        x: 12
        y: words.y + words.implicitHeight + 4
        z: 1
        spacing: 12
        Repeater {
            model: line.buttons
            Text {
                required property var modelData
                required property int index
                text: "[" + modelData.text + "]"
                font: Ui.font
                color: hover.containsMouse ? Colors.base07 : Colors.base0D
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: line.pressed(parent.index) }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: if (!flash.running) flash.start()
    }
    SequentialAnimation {
        id: flash
        PauseAnimation { duration: 160 }
        ScriptAction { script: line.clicked() }
    }
}

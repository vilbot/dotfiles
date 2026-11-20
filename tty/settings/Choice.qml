// One of a few: side by side boxes, the chosen one lit. `choices`: [[value, label], ...].
import QtQuick

Row {
    id: choice
    property var choices: []
    property var value
    property bool active: false
    signal picked(var value)
    spacing: 0

    readonly property int index: choices.findIndex(c => c[0] === value)
    function step(by) {
        const i = Math.max(0, Math.min(choices.length - 1, index + by))
        if (i !== index) picked(choices[i][0])
    }

    Repeater {
        model: choice.choices
        delegate: Rectangle {
            id: box
            required property var modelData
            required property int index
            readonly property bool on: choice.value === modelData[0]
            width: label.implicitWidth + 24
            height: 24
            color: on ? Qt.alpha(Style.accent, 0.2) : area.containsMouse ? Style.line : "transparent"
            border.width: 1
            border.color: on ? Style.accent : Style.faint
            Behavior on color { ColorAnimation { duration: Style.quick } }
            Text {
                id: label
                anchors.centerIn: parent
                text: box.modelData[1]
                font: Style.font
                color: box.on ? Style.strong : area.containsMouse ? Style.text : Style.dim
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: choice.picked(box.modelData[0])
            }
        }
    }
}

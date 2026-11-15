// A row of Choice words that wraps. choices: [[value, label], ...]; picked(value) on a click.
import QtQuick
import QtQuick.Layouts

Flow {
    id: root
    property var choices: []
    property var isSelected: value => false
    signal picked(var value)
    Layout.fillWidth: true
    spacing: 14
    Repeater {
        model: root.choices
        delegate: Choice {
            required property var modelData
            text: modelData[1]
            selected: root.isSelected(modelData[0])
            onClicked: root.picked(modelData[0])
        }
    }
}

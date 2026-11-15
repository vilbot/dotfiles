import QtQuick
import QtQuick.Layouts
import "schema.js" as Schema

ColumnLayout {
    spacing: 0
    Repeater {
        model: Schema.animLeaves
        delegate: AnimationRow { required property var modelData; info: modelData }
    }
}

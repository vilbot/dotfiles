// A page of Hyprland options (schema.js): headings and option rows.
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    property var options: []
    spacing: 0

    Repeater {
        model: parent.options
        delegate: Loader {
            required property var modelData
            Layout.fillWidth: true
            visible: HyprSettings.shown(modelData)
            sourceComponent: modelData.heading ? heading : row
            onLoaded: item.opt = modelData
        }
    }

    Component {
        id: heading
        Heading {
            property var opt: ({})
            Layout.topMargin: 26
            text: (opt.heading ?? "").toUpperCase()
        }
    }
    Component { id: row; OptionRow {} }
}

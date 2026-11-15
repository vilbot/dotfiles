// A small letter-spaced section title over a hairline: "SOUND", "WINDOWS".
import QtQuick
import QtQuick.Layouts
import qs.services

ColumnLayout {
    property alias text: label.text
    property alias color: label.color
    Layout.fillWidth: true
    spacing: 4
    Text { id: label; color: Theme.inkFaint; font: Theme.textCaps }
    Divider {}
}

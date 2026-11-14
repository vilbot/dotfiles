// A one-color icon in the theme's ink, so it follows dark / light mode. Takes only the shape of
// an icon-theme icon (use the -symbolic ones): the Breeze icons themselves are dark gray and
// would vanish on the dark bar. Same API as IconImage: source + implicitSize.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

Item {
    id: root
    property alias source: shape.source
    property int implicitSize: 16
    property color color: Theme.ink
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    IconImage { id: shape; anchors.fill: parent; visible: false; layer.enabled: true }
    Rectangle { id: paint; anchors.fill: parent; color: root.color; visible: false; layer.enabled: true }
    MultiEffect {
        anchors.fill: parent
        source: paint
        maskEnabled: true
        maskSource: shape
        // threshold 0.5 with full spread = the mask follows the icon's own alpha (soft edges)
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}

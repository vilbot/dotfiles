// On/off switch: a small pill, ink when on. Emits toggled(newValue); the owner sets `checked`.
import QtQuick
import qs.services

Rectangle {
    id: t
    property bool checked: false
    property bool enabled: true
    signal toggled(bool value)

    implicitWidth: 30
    implicitHeight: 16
    radius: height / 2
    color: checked ? Theme.ink : "transparent"
    border { color: checked ? Theme.ink : Theme.inkFaint; width: 1 }
    opacity: enabled ? 1 : 0.4

    Rectangle {
        width: 10; height: 10; radius: 5
        anchors.verticalCenter: parent.verticalCenter
        x: t.checked ? t.width - width - 3 : 3
        color: t.checked ? Theme.paper : Theme.inkFaint
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        enabled: t.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: t.toggled(!t.checked)
    }
}

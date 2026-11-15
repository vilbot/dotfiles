// "3 NOTICES   Friday, 13 November   17:20". When there are notifications, click to open the
// history (like the Mac's clock / notification center); with none, the clock isn't clickable.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services

Item {
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        Text {
            visible: Notifications.count > 0
            text: Notifications.count + (Notifications.count === 1 ? " NOTICE" : " NOTICES")
            color: Panels.historyOpen ? Theme.ink : Theme.inkDim
            font: Theme.textCaps
        }
        Text {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.inkDim
            font: Theme.textItalic
        }
        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.ink
            font: Theme.text
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: Notifications.count > 0 || Panels.historyOpen
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.historyOpen = !Panels.historyOpen
    }
}

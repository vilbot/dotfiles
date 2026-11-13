// "3 NOTICES   Friday, 13 November   17:20". When there are notifications, click to open the
// history (like the Mac's clock / notification center); with none, the clock isn't clickable.
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        Text {
            visible: NotifState.count > 0
            text: NotifState.count + (NotifState.count === 1 ? " NOTICE" : " NOTICES")
            color: NotifState.historyOpen ? Theme.ink : Theme.inkDim
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
        enabled: NotifState.count > 0 || NotifState.historyOpen
        cursorShape: Qt.PointingHandCursor
        onClicked: NotifState.historyOpen = !NotifState.historyOpen
    }
}

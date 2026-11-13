// "Friday, 13 November   17:20": date in italic, time upright.
import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    spacing: 12
    SystemClock { id: clock; precision: SystemClock.Minutes }

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

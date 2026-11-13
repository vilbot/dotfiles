// Shared notification state, so the bar (count, clock click) can reach Notifications.qml.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool historyOpen: false
    property int count: 0          // notifications in the history (set by Notifications.qml)
}

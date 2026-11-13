// Which pop-over panels are open. One at a time: opening the control center closes the
// notification history and the other way round.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool controlOpen: false     // ControlCenter.qml
    property bool settingsOpen: false    // Settings.qml (a normal window, can stay open)

    function toggleControl() {
        controlOpen = !controlOpen
        if (controlOpen) NotifState.historyOpen = false
    }

    Connections {
        target: NotifState
        function onHistoryOpenChanged() { if (NotifState.historyOpen) Panels.controlOpen = false }
    }
}

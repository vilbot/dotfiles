// The pop-over panels and the settings window. The control center and the notification history
// take turns: opening one closes the other.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool controlOpen: false
    property bool historyOpen: false
    property bool settingsOpen: false
    property string settingsPage: ""     // the page the settings window opens at

    onControlOpenChanged: if (controlOpen) historyOpen = false
    onHistoryOpenChanged: if (historyOpen) controlOpen = false

    function openSettings(page) { settingsPage = page ?? ""; settingsOpen = true }
}

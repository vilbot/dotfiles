// Every notification still around, newest first: click the clock or the notice count in the bar.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

PanelWindow {
    screen: Screens.focused
    visible: Panels.historyOpen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: Panels.historyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal      // below the bar
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    MouseArea { anchors.fill: parent; onClicked: Panels.historyOpen = false }
    Item {
        anchors.fill: parent
        focus: Panels.historyOpen
        Keys.onEscapePressed: Panels.historyOpen = false
    }

    Rectangle {
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom; margins: 10 }
        width: Theme.notificationWidth + 2 * 16
        color: Theme.wall
        border { color: Theme.hairline; width: 1 }
        radius: 2
        MouseArea { anchors.fill: parent }   // clicks on the panel don't close it

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Notifications"; color: Theme.ink; font: Theme.heading }
                LinkText {
                    visible: Notifications.count > 0
                    text: "Clear all"
                    onClicked: Notifications.clearAll()
                }
            }
            Divider {}

            Text {
                visible: Notifications.count === 0
                Layout.topMargin: 8
                text: "Nothing new."
                color: Theme.inkFaint
                font: Theme.textItalic
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 10
                model: Notifications.history
                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    time: Notifications.times[modelData.id] ?? ""
                }
            }
        }
    }
}

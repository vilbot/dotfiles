// New notifications, top right under the bar, until their timeout (hidden while the history is open).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    screen: Screens.focused
    visible: Notifications.popups.count > 0 && !Panels.historyOpen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    exclusionMode: ExclusionMode.Normal      // below the bar, not over it
    anchors { top: true; right: true }
    margins { top: 10; right: 10 }
    implicitWidth: Theme.notificationWidth
    implicitHeight: Math.max(1, list.contentHeight)
    color: "transparent"

    ListView {
        id: list
        anchors.fill: parent
        interactive: false
        spacing: 10
        model: Notifications.popups

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
            NumberAnimation { property: "x"; from: 30; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
        }

        delegate: Loader {
            id: slot
            required property int nid
            readonly property var notification: Notifications.find(nid)
            active: notification !== null
            sourceComponent: NotificationCard {
                notification: slot.notification
                timed: true
                onTimedOut: {
                    const n = slot.notification
                    Notifications.removePopup(slot.nid)
                    if (n && n.transient) n.expire()
                }
            }
        }
    }
}

// Notification server, popups and history (Hyprland; KDE has its own).
// - Popups appear top-right under the bar and leave after their timeout, but the notification
//   stays in the history (except ones the app marks transient).
// - History: click the clock or the notice count in the bar, or `qs ipc call notifications
//   toggle`. Newest first, with arrival time; "Clear all". Keeps the latest `historyLimit`.
// - Dismissing a card (× / right-click) removes it everywhere and tells the app.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Scope {
    id: root
    readonly property int cardWidth: 380
    readonly property int historyLimit: 50
    readonly property var screenNow: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                                     ?? Quickshell.screens[0]
    property var times: ({})             // notification id -> "HH:mm" it arrived
    readonly property var history: server.trackedNotifications.values.slice().reverse()   // newest first

    NotificationServer {
        id: server
        keepOnReload: true          // survive Quickshell config reloads
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            root.times[n.id] = Qt.formatTime(new Date(), "HH:mm")
            n.closed.connect(() => root.removePopup(n.id))
            popups.append({ nid: n.id })
            // cap the history: drop the oldest
            const all = server.trackedNotifications.values
            for (let i = 0; i < all.length - root.historyLimit; i++) all[i].dismiss()
        }
    }

    Binding { target: NotifState; property: "count"; value: server.trackedNotifications.values.length }

    function find(nid) { return server.trackedNotifications.values.find(n => n.id === nid) ?? null }
    function removePopup(nid) {
        for (let i = 0; i < popups.count; i++)
            if (popups.get(i).nid === nid) { popups.remove(i); return }
    }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
        NotifState.historyOpen = false
    }

    ListModel { id: popups }   // ids of notifications currently shown as popups

    IpcHandler {
        target: "notifications"
        function toggle(): void { NotifState.historyOpen = !NotifState.historyOpen }
        function open(): void { NotifState.historyOpen = true }
        function close(): void { NotifState.historyOpen = false }
        function clear(): void { root.clearAll() }
    }

    // ---- popups -----------------------------------------------------------------------------
    PanelWindow {
        screen: root.screenNow
        visible: popups.count > 0 && !NotifState.historyOpen

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        exclusionMode: ExclusionMode.Normal      // sits below the bar, not over it
        anchors { top: true; right: true }
        margins { top: 10; right: 10 }
        implicitWidth: root.cardWidth
        implicitHeight: Math.max(1, list.contentHeight)
        color: "transparent"

        ListView {
            id: list
            anchors.fill: parent
            interactive: false
            spacing: 10
            model: popups

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
                readonly property var notification: root.find(nid)
                width: root.cardWidth
                active: notification !== null
                sourceComponent: NotificationCard {
                    width: root.cardWidth
                    notification: slot.notification
                    timed: true
                    onTimedOut: {
                        const n = slot.notification
                        root.removePopup(slot.nid)
                        if (n && n.transient) n.expire()
                    }
                }
            }
        }
    }

    // ---- history panel ----------------------------------------------------------------------
    PanelWindow {
        screen: root.screenNow
        visible: NotifState.historyOpen

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        WlrLayershell.keyboardFocus: NotifState.historyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal      // below the bar
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // click outside the panel closes it
        MouseArea { anchors.fill: parent; onClicked: NotifState.historyOpen = false }

        Item {
            anchors.fill: parent
            focus: NotifState.historyOpen
            Keys.onEscapePressed: NotifState.historyOpen = false
        }

        Rectangle {
            id: panel
            anchors { top: parent.top; right: parent.right; bottom: parent.bottom; margins: 10 }
            width: root.cardWidth + 2 * 16
            color: Theme.wall
            border { color: Theme.hairline; width: 1 }
            radius: 2
            MouseArea { anchors.fill: parent }   // clicks on the panel don't close it

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Notifications"
                        color: Theme.ink
                        font: Qt.font({ family: Theme.fontFamily, pixelSize: 24, italic: true })
                    }
                    Text {
                        visible: root.history.length > 0
                        text: "Clear all"
                        color: clearArea.containsMouse ? Theme.ink : Theme.inkDim
                        font: Theme.textItalic
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAll()
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

                Text {
                    visible: root.history.length === 0
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
                    model: root.history
                    delegate: NotificationCard {
                        required property var modelData
                        width: root.cardWidth
                        notification: modelData
                        time: root.times[modelData.id] ?? ""
                    }
                }
            }
        }
    }
}

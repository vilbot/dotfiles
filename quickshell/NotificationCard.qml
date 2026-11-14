// One notification, styled like a gallery label. Used for popups and in the history panel.
// Click: run the app's default action (or dismiss). Right-click or ×: dismiss for good.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: card
    required property Notification notification
    property string time: ""              // "17:42", shown in the history panel
    property bool timed: false            // popup: emit timedOut() after the timeout
    property int defaultTimeout: 6000     // ms, when the app doesn't say
    signal timedOut()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notification.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    // Many apps (and notify-send -i) send their icon as the notification "image". Quickshell wraps
    // both kinds as image://icon/<x>: a theme icon name (small, next to the app name) or a file
    // path, which is a real picture (album art, avatar, screenshot: big slot on the right).
    readonly property string iconRef: notification.image.startsWith("image://icon/")
                                    ? notification.image.slice("image://icon/".length) : ""
    readonly property bool imageIsIcon: iconRef !== "" && !iconRef.startsWith("/") && !iconRef.startsWith("file:")
    readonly property string icon: notification.appIcon === "" ? (imageIsIcon ? notification.image : "")
                                 : notification.appIcon.includes("/") ? notification.appIcon
                                 : Quickshell.iconPath(notification.appIcon, true)
    readonly property string picture: imageIsIcon ? ""
                                    : iconRef.startsWith("/") ? "file://" + iconRef
                                    : iconRef !== "" ? iconRef : notification.image

    implicitHeight: body.implicitHeight + 28
    color: Theme.panel
    border { color: Theme.hairline; width: 1 }
    radius: 2

    // critical: a thin vermilion rule down the left edge
    Rectangle {
        visible: card.critical
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: Theme.urgent
    }

    Timer {
        // expireTimeout is in seconds; <= 0 means "server default". Critical ones stay.
        interval: card.notification.expireTimeout > 0 ? card.notification.expireTimeout * 1000 : card.defaultTimeout
        running: card.timed && !card.critical && !hover.hovered
        onTriggered: card.timedOut()
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && card.defaultAction) card.defaultAction.invoke()
            else card.notification.dismiss()
        }
    }

    RowLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; leftMargin: 18 }
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            // app line: icon, NAME IN SMALL CAPS, time, ×
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                IconImage {
                    visible: card.icon !== ""
                    implicitSize: 14
                    source: card.icon
                }
                Text {
                    Layout.fillWidth: true
                    text: (card.notification.appName || "Notification").toUpperCase()
                    elide: Text.ElideRight
                    color: Theme.inkFaint
                    font: Theme.textCaps
                }
                Text {
                    visible: card.time !== ""
                    text: card.time
                    color: Theme.inkFaint
                    font: Theme.textItalic
                }
                Text {
                    text: "×"
                    color: close.containsMouse ? Theme.ink : Theme.inkFaint
                    font: Theme.text
                    MouseArea {
                        id: close
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.notification.dismiss()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.summary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.ink
                font: Qt.font({ family: Theme.fontFamily, pixelSize: Theme.fontSize + 1, bold: true })
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.body
                textFormat: Text.StyledText   // apps may send <b>, <i>, <a>
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
                color: Theme.inkDim
                linkColor: Theme.ink
                font: Theme.text
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // action buttons as italic links: "Reply   Mark as read"
            Row {
                visible: card.buttons.length > 0
                topPadding: 4
                spacing: 18
                Repeater {
                    model: card.buttons
                    Text {
                        id: actionText
                        required property var modelData
                        text: modelData.text
                        color: Theme.ink
                        font: Theme.textItalic
                        MouseArea {
                            id: act
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: actionText.modelData.invoke()
                        }
                        Rectangle {   // underline on hover
                            anchors { left: parent.left; right: parent.right; top: parent.bottom }
                            height: 1
                            color: Theme.ink
                            visible: act.containsMouse
                        }
                    }
                }
            }
        }

        // picture sent with the notification (album art, avatar, screenshot ...)
        Image {
            visible: card.picture !== ""
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            source: card.picture
            fillMode: Image.PreserveAspectCrop
            sourceSize { width: 112; height: 112 }
        }
    }
}

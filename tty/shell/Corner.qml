// The top right corner, under the bar: the volume and the layout while they change, and
// notification popups; or, while it's open (the [n] in the bar), the notification list with
// do-not-disturb. Everything comes and goes like the launcher: a quick fade with a small slide.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

PanelWindow {
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    readonly property bool wanted: Status.volumeShown || Status.layoutShown || Notes.listOpen || Notes.popups.count > 0
    visible: wanted || linger.running   // stays up while the last box fades out
    onWantedChanged: if (!wanted) linger.restart()
    Timer { id: linger; interval: Ui.quick + 40 }
    anchors { top: true; right: true }
    margins { top: 8; right: 8 }
    implicitWidth: 460
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tty-corner"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: column }   // clicks next to the boxes go to the windows below

    Column {
        id: column
        anchors.right: parent.right
        width: parent.width
        spacing: 6
        move: Transition { NumberAnimation { properties: "y"; duration: Ui.quick; easing.type: Easing.OutCubic } }

        Line { anchors.right: parent.right; text: Status.volume; shown: Status.volumeShown }
        Line { anchors.right: parent.right; text: Status.layout; shown: Status.layoutShown }

        // ---- the list: drops down like the launcher's results ----
        Rectangle {
            id: list
            anchors.right: parent.right
            width: parent.width
            height: Notes.listOpen ? listColumn.implicitHeight + 2 : 0
            visible: height > 0
            clip: true
            color: Colors.base00
            border { color: Colors.base03; width: 1 }
            Behavior on height { NumberAnimation { duration: Ui.quick; easing.type: Easing.OutCubic } }
            Column {
                id: listColumn
                x: 1; y: 1
                width: parent.width - 2
                opacity: Notes.listOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Ui.quick } }
                Item {   // header: do not disturb, clear
                    width: parent.width
                    height: Ui.row + 4
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: (Notes.dnd ? "[x]" : "[ ]") + " do not disturb"
                        font: Ui.font
                        color: Notes.dnd ? Colors.base0E : Colors.base05
                        Behavior on color { ColorAnimation { duration: Ui.quick } }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: Notes.dnd = !Notes.dnd }
                    }
                    Text {
                        visible: Notes.list.length > 0
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "clear all"
                        font: Ui.font
                        color: Colors.base05
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: Notes.clear() }
                    }
                }
                Text {
                    visible: Notes.list.length === 0
                    x: 12
                    height: Ui.row
                    verticalAlignment: Text.AlignVCenter
                    text: "nothing new"
                    font: Ui.font
                    color: Colors.base04
                }
                Repeater {
                    model: Notes.list
                    Line {
                        required property var modelData
                        width: listColumn.width
                        maxWidth: listColumn.width
                        border.width: 0
                        title: modelData.appName ? modelData.appName + ": " + modelData.summary : modelData.summary
                        text: modelData.body
                        onClicked: Notes.open(modelData)
                    }
                }
            }
        }

        // ---- popups: in like the launcher, out the same way before they're dropped ----
        Repeater {
            model: Notes.popups
            Line {
                id: pop
                required property int nid
                readonly property var n: Notes.find(nid)
                property bool leaving: false
                anchors.right: parent.right
                shown: false
                Component.onCompleted: shown = Qt.binding(() => !pop.leaving && !Notes.listOpen)
                title: n ? (n.appName ? n.appName + ": " + n.summary : n.summary) : ""
                text: n?.body ?? ""
                ink: n?.urgency === NotificationUrgency.Critical ? Colors.base08 : Colors.base06
                onClicked: if (n) Notes.open(n)
                Timer {   // the popup leaves; the notification stays in the list
                    running: pop.n && pop.n.urgency !== NotificationUrgency.Critical && !pop.leaving
                    interval: pop.n && pop.n.expireTimeout > 0 ? pop.n.expireTimeout * 1000 : 6000
                    onTriggered: pop.leaving = true
                }
                Timer { running: pop.leaving && !pop.visible; interval: 1; onTriggered: Notes.unpop(pop.nid) }
            }
        }
    }
}

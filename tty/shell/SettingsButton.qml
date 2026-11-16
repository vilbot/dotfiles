// The settings button in the bar: a small dim speaker showing the volume; when something's wrong, red icons for
// what is (muted, offline; both when it's both). Click: the settings panel (tty/panel.sh, as F5).
import QtQuick
import Quickshell

Item {
    id: button
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    // icons from a Nerd Font (Hack has none): the speaker shows the volume (low, medium, high),
    // muted and offline replace it in red
    readonly property var problems: [Status.muted ? "\u{f0581}" : "", Status.online ? "" : "\u{f0318}"].filter(p => p)
    readonly property string speaker: Status.percent < 34 ? "\u{f057f}" : Status.percent < 67 ? "\u{f0580}" : "\u{f057e}"
    readonly property var icons: problems.length ? problems : [speaker]

    Row {
        id: row
        spacing: 6
    Repeater {
        model: button.icons
        Text {
            required property string modelData
            text: modelData
            font { family: "MesloLGS Nerd Font Mono"; pixelSize: 15 }
            color: button.problems.length ? Colors.base08 : mouse.containsMouse ? Colors.base06 : Colors.base04
            // comes in like the launcher: a fade with a small slide
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Ui.quick } }
            Behavior on color { ColorAnimation { duration: Ui.quick } }
            transform: Translate { y: 6 * (1 - opacity) }
        }
    }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        onClicked: Quickshell.execDetached([Quickshell.shellDir + "/../panel.sh"])
    }
}

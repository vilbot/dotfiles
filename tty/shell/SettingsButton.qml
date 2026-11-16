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
    // Font Awesome's speakers: one speaker size, the waves added (Material's resize the speaker)
    readonly property var problems: [Status.muted ? "\u{eee8}" : "", Status.online ? "" : "\u{f0318}"].filter(p => p)
    readonly property string speaker: Status.percent < 34 ? "\u{f026}" : Status.percent < 67 ? "\u{f027}" : "\u{f028}"
    readonly property var icons: problems.length ? problems : [speaker]

    Row {
        id: row
        spacing: 6
    Repeater {
        model: button.icons
        Text {
            required property string modelData
            text: modelData
            font { family: "MesloLGS Nerd Font Mono"; pixelSize: 17 }
            // one width and size for every icon: the volume levels' glyphs differ
            width: 18
            height: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
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

// The settings icons in the bar, one per tab of the settings panel (tty/panel.sh), in its order;
// a click opens the panel on that tab (a second click closes it). Help and theme have none.
//   sound      the volume (low, medium, high); muted: red
//   bluetooth  always the same
//   network    red when offline
//   update     grey: nothing to do, green: updates, yellow: the update asks you something (a
//              password, a y/n), red: the last update failed (until you've looked at it)
import QtQuick
import Quickshell

Row {
    id: icons
    spacing: 10
    // glyphs from a Nerd Font (Hack has none); Font Awesome's speakers: one speaker size, the waves
    // added (Material's resize the speaker)
    readonly property string speaker: Status.muted ? "\u{eee8}" : Status.percent < 34 ? "\u{f026}" : Status.percent < 67 ? "\u{f027}" : "\u{f028}"
    readonly property var model: [
        { tab: "sound", glyph: speaker, color: Status.muted ? Colors.base08 : "" },
        { tab: "bluetooth", glyph: "\u{f00af}", color: "" },
        { tab: "network", glyph: Status.online ? "\u{f0317}" : "\u{f0319}", color: Status.online ? "" : Colors.base08 },
        { tab: "update", glyph: "\u{f06b0}",
          color: ({ failed: Colors.base08, waiting: Colors.base0E, available: Colors.base0B })[Status.update] ?? "" },
    ]

    Repeater {
        model: icons.model
        Text {
            required property var modelData
            text: modelData.glyph
            font { family: "MesloLGS Nerd Font Mono"; pixelSize: 17 }
            // one width and size for every icon: the glyphs differ
            width: 18
            height: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: modelData.color !== "" ? modelData.color : mouse.containsMouse ? Colors.base06 : Colors.base04
            // comes in like the launcher: a fade with a small slide
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Ui.quick } }
            Behavior on color { ColorAnimation { duration: Ui.quick } }
            transform: Translate { y: 6 * (1 - opacity) }
            MouseArea {
                id: mouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                onClicked: Quickshell.execDetached([Quickshell.shellDir + "/../panel.sh", parent.modelData.tab])
            }
        }
    }
}

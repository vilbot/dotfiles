// Current keyboard layout (US / SV). Click to switch, same as Opt+Space.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Text {
    id: root
    property string layout: ""   // full xkb name, e.g. "English (US)", "Swedish (Swerty)"

    // "English (US)" -> "US", "Swedish (Swerty)" -> "SV"
    function short(name) {
        if (name.startsWith("English")) return "US"
        if (name.startsWith("Swedish")) return "SV"
        return name.slice(0, 2).toUpperCase()
    }

    text: short(layout)
    color: Theme.inkDim
    font: Theme.textCaps

    // initial value: the main keyboard's active keymap
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kbs = JSON.parse(text).keyboards
                const kb = kbs.find(k => k.main) ?? kbs[0]
                if (kb) root.layout = kb.active_keymap
            }
        }
    }

    // updates: Hyprland event "activelayout>>KEYBOARD,LAYOUT"
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            const data = event.data
            root.layout = data.slice(data.lastIndexOf(",") + 1)
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
    }
}

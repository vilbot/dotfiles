// What the bar's settings button and the corner show: the volume (a popup while it changes),
// muted, online, and the keyboard layout (a popup when it changes). A popup's text stays after
// it hides, so it can fade out with its words still on it.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Singleton {
    id: root
    property string volume: ""         // "vol [#####-----]  50%"
    property bool volumeShown: false
    property string layout: ""         // "Sweden - Swerty"
    property bool layoutShown: false

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round((sink?.audio?.volume ?? 0) * 100)

    function bar(v) {
        const n = Math.round(Math.max(0, Math.min(1, v)) * 20)
        return "[" + "#".repeat(n) + "-".repeat(20 - n) + "]"
    }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() {
            // from the volume itself: `percent` (a binding) may not have caught up yet
            const v = root.sink.audio.volume
            root.volume = "vol " + root.bar(v) + " " + String(Math.round(v * 100)).padStart(3) + "%"
            root.volumeShown = true
            volumeTimer.restart()
        }
    }
    Timer { id: volumeTimer; interval: 1500; onTriggered: root.volumeShown = false }

    // ---- online: NetworkManager's connectivity check, asked every few seconds -----------
    property bool online: true
    Process {
        id: connectivity
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general"]
        stdout: StdioCollector { onStreamFinished: root.online = text.trim() === "full" || text.trim() === "unknown" }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: connectivity.running = true }

    // ---- the keyboard layout --------------------------------------------------------------
    // Every keyboard reports its layout, and a Bluetooth headset's media buttons count as one (it
    // even becomes Hyprland's "main" keyboard). All typing goes through mackeys' virtual keyboard,
    // so only its layout counts, and only when it changed.
    readonly property string typingKeyboard: "mackeys-virtual-keyboard"
    property string current: ""
    Connections {
        target: Hyprland
        function onRawEvent(event) {   // "activelayout>>KEYBOARD,LAYOUT"
            if (event.name !== "activelayout") return
            const i = event.data.lastIndexOf(",")
            const keyboard = event.data.slice(0, i), name = event.data.slice(i + 1)
            if (keyboard !== root.typingKeyboard || name === root.current) return
            root.current = name
            root.layout = name
            root.layoutShown = true
            layoutTimer.restart()
        }
    }
    Timer { id: layoutTimer; interval: 1200; onTriggered: root.layoutShown = false }
}

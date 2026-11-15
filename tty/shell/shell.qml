// The "None" desktop's only drawn-on-top things, as plain text in the top right corner:
// the volume while it changes, "muted" until clicked away, the keyboard layout when it changes,
// and notifications. Started by tty/hyprland.lua; run by hand to see errors:  qs -p ~/dotfiles/tty/shell
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    // ---- what is shown -------------------------------------------------------------------
    property string volume: ""        // "vol [#####-----]  50%" while it changes
    property bool muteShown: false    // muted, and not clicked away yet
    property string layout: ""        // the keyboard layout, right after it changed

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    function bar(v) {
        const n = Math.round(Math.max(0, Math.min(1, v)) * 20)
        return "[" + "#".repeat(n) + "-".repeat(20 - n) + "]"
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() {
            const v = root.sink.audio.volume
            root.volume = "vol " + root.bar(v) + " " + String(Math.round(v * 100)).padStart(3) + "%"
            volumeTimer.restart()
        }
        function onMutedChanged() { root.muteShown = root.sink.audio.muted }
    }
    Timer { id: volumeTimer; interval: 1500; onTriggered: root.volume = "" }

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
            layoutTimer.restart()
        }
    }
    Timer { id: layoutTimer; interval: 1200; onTriggered: root.layout = "" }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        onNotification: n => { n.tracked = true }
    }

    // ---- the corner ----------------------------------------------------------------------
    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: column.children.some(c => c.visible)
        anchors { top: true; right: true }
        margins { top: 8; right: 8 }
        implicitWidth: 460
        implicitHeight: column.implicitHeight
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "tty-shell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: column }   // clicks next to the lines go to the windows below

        Column {
            id: column
            anchors.right: parent.right
            width: parent.width
            spacing: 6

            Line { text: root.volume; visible: text !== "" }
            Line {
                text: "muted"
                visible: root.muteShown
                ink: Colors.base0E
                onClicked: root.muteShown = false     // only hides this; the sound stays muted
            }
            Line { text: root.layout; visible: text !== "" }

            Repeater {
                model: server.trackedNotifications
                Line {
                    required property var modelData
                    readonly property var n: modelData
                    title: n.appName ? n.appName + ": " + n.summary : n.summary
                    text: n.body
                    ink: n.urgency === NotificationUrgency.Critical ? Colors.base08 : Colors.base06
                    // click: the app's default action if it has one; either way it goes away
                    onClicked: {
                        const act = n.actions.find(a => a.identifier === "default")
                        if (act) act.invoke()
                        n.dismiss()
                    }
                    Timer {
                        running: n.urgency !== NotificationUrgency.Critical
                        interval: n.expireTimeout > 0 ? n.expireTimeout * 1000 : 6000
                        onTriggered: n.expire()
                    }
                }
            }
        }
    }
}

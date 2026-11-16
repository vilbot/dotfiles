// What the bar shows: desktops on the left, the focused app's name in the middle (the launcher
// opens over it, LauncherWindow.qml: the name gives way to the prompt), and on the right the
// notifications, the settings button and the clock. Drawn by Bar.qml along the top of None, and
// by the lock (LockScreen.qml), which shows only the desktops, the name and the clock.
// Changes move the way the launcher does: a quick fade with a small slide (Ui.quick).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: content
    property bool here: true         // the focused monitor's bar
    property bool launching: false   // the launcher is open over it
    property bool minimal: false     // only desktops, name, clock (the lock, the login screen)
    implicitHeight: Ui.barHeight

    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Colors.base02 }

    // ---- left: desktops; the highlight slides to the focused one -------------------------
    Item {
        id: desks
        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
        width: row.width
        height: row.height
        readonly property int focusedIndex: (Hyprland.focusedWorkspace?.id ?? 1) - 1

        Rectangle {
            readonly property var cell: cells.count > 0 ? cells.itemAt(desks.focusedIndex) : null  // count: redo once they exist
            visible: content.here && cell && desks.focusedIndex >= 0 && desks.focusedIndex < Ui.desktops
            x: cell?.x ?? 0
            width: cell?.width ?? 0
            height: row.height
            color: Colors.base0C
            Behavior on x { NumberAnimation { duration: Ui.quick; easing.type: Easing.OutCubic } }
        }
        Row {
            id: row
            Repeater {
                id: cells
                model: Ui.desktops
                Text {
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                    readonly property bool focused: content.here && desks.focusedIndex === index
                    text: " " + wsId + " "
                    font: focused ? Ui.bold : Ui.font
                    color: focused ? Colors.base00 : (ws?.toplevels?.values?.length ?? 0) > 0 ? Colors.base06 : Colors.base03
                    Behavior on color { ColorAnimation { duration: Ui.quick } }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${parent.wsId} })`)
                    }
                }
            }
        }
    }

    // ---- middle: the focused app and its title, where the launcher's text goes ------------
    // "Terminal  ~/dotfiles", "Terminal  • options.lua" (nvim's title, • = unsaved), "Google
    // Chrome  Inbox - Gmail". It starts where you'd type in the launcher, so opening the launcher
    // looks like the title being replaced by what you type.
    Item {
        id: middle
        anchors.centerIn: parent
        width: Ui.centerWidth
        height: parent.height

        // the focused window, from Hyprland's own events (Quickshell's activeToplevel lags a focus
        // change behind): "activewindow>>CLASS,TITLE" (empty on an empty desktop),
        // "activewindowv2>>ADDRESS", and "windowtitlev2>>ADDRESS,TITLE" when a title changes
        property string cls: ""
        property string title: ""
        property string address: ""
        function after(data) { const i = data.indexOf(","); return i < 0 ? ["", data] : [data.slice(0, i), data.slice(i + 1)] }
        Connections {
            target: Hyprland
            function onRawEvent(event) {
                if (event.name === "activewindow") [middle.cls, middle.title] = middle.after(event.data)
                else if (event.name === "activewindowv2") middle.address = event.data
                else if (event.name === "windowtitlev2") {
                    const [addr, title] = middle.after(event.data)
                    if (addr === middle.address) middle.title = title
                }
            }
        }
        Process {
            running: true
            command: ["hyprctl", "activewindow", "-j"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const w = JSON.parse(text)
                        middle.cls = w.class ?? ""; middle.title = w.title ?? ""; middle.address = (w.address ?? "").replace(/^0x/, "")
                    } catch (e) {}
                }
            }
        }
        readonly property string appName: {
            if (cls === "") return ""
            if (cls === "tty-session" || cls === "foot") return "Terminal"
            if (cls === "tty-panel") return "Settings"
            return DesktopEntries.heuristicLookup(cls)?.name ?? cls
        }
        // the title without the app's name the app adds itself (" - Google Chrome")
        readonly property string detail: {
            let t = title.trim()
            for (const name of [appName, cls]) {
                if (!name) continue
                for (const sep of [" - ", " — ", " – "]) if (t.endsWith(sep + name)) t = t.slice(0, -(sep.length + name.length))
            }
            return t === appName ? "" : t
        }
        // another window: the old one fades out and up, the new one in from below (a title that
        // changes in place, like nvim's • for unsaved, just changes)
        property string shownName: appName
        property string shownDetail: detail
        onDetailChanged: if (!swap.running) shownDetail = detail
        property real lift: 0
        onAppNameChanged: swap.restart()
        onAddressChanged: swap.restart()
        SequentialAnimation {
            id: swap
            ParallelAnimation {
                NumberAnimation { target: name; property: "fade"; to: 0; duration: Ui.quick / 2 }
                NumberAnimation { target: middle; property: "lift"; to: -6; duration: Ui.quick / 2 }
            }
            ScriptAction { script: { middle.shownName = middle.appName; middle.shownDetail = middle.detail } }
            PropertyAction { target: middle; property: "lift"; value: 6 }
            ParallelAnimation {
                NumberAnimation { target: name; property: "fade"; to: 1; duration: Ui.quick }
                NumberAnimation { target: middle; property: "lift"; to: 0; duration: Ui.quick; easing.type: Easing.OutCubic }
            }
        }

        // where the launcher's text starts: its "> " (LauncherWindow.qml: 12 + ">" + 8)
        FontMetrics { id: caretMetrics; font: Ui.bold }
        Row {
            id: name
            property real fade: 1
            anchors { left: parent.left; leftMargin: 12 + caretMetrics.advanceWidth(">") + 8; right: parent.right }
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: content.launching ? -6 : middle.lift
            spacing: 10
            clip: true
            opacity: content.launching ? 0 : fade
            Behavior on opacity { enabled: !swap.running; NumberAnimation { duration: Ui.quick } }
            Behavior on anchors.verticalCenterOffset {
                enabled: !swap.running
                NumberAnimation { duration: Ui.quick; easing.type: Easing.OutCubic }
            }
            Text { text: middle.shownName; font: Ui.bold; color: Colors.base06 }
            Text {
                text: middle.shownDetail
                font: Ui.font
                color: Colors.base04
                elide: Text.ElideRight
                width: Math.min(implicitWidth, name.width - x)
            }
        }
    }

    // ---- right: settings, notifications, the clock ---------------------------------------
    Row {
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 14
        // notifications (only when there are any), then the settings button; a hidden one takes no room
        Loader { active: !content.minimal; source: "NoteCount.qml"; visible: !content.minimal && (Notes.list.length > 0 || Notes.dnd); anchors.verticalCenter: parent.verticalCenter }
        Loader { active: !content.minimal; source: "SettingsButton.qml"; anchors.verticalCenter: parent.verticalCenter }
        Text {
            id: clock
            font: Ui.font
            color: Colors.base06
            text: Qt.formatDateTime(clockTick.now, "ddd d MMM  HH:mm")
        }
    }
    SystemClock { id: clockTick; precision: SystemClock.Minutes; readonly property var now: date }
}

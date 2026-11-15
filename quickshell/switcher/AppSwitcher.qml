// Cmd+Tab app switcher (like the Mac's).
// - Hold Cmd, tap Tab to move right (Shift+Tab left), let go of Cmd: switch to that app's most
//   recently used window. A quick Cmd+Tab goes back to the previous app. One icon per app, most
//   recently used first.
// - Cmd+` while it's open: show the chosen app's windows instead (a small picture of each with
//   its title); ` / Shift+` (or Tab / Shift+Tab) move between them, letting go of Cmd switches to
//   that window. Cmd+` with the switcher closed shows the focused app's windows.
//   Cmd+Tab in the windows view goes back to the app icons.
// - Esc cancels; clicking an app or window switches to it.
//
// Keys: mackeys (keys/remap.toml: app.switch.*) runs these global shortcuts, and switcher-commit
// when Cmd is let go.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.widgets

Scope {
    id: root
    property bool showing: false
    property string mode: "apps"          // "apps" | "windows"
    property int current: 0
    property var apps: []                 // snapshot while open: [{ cls, icon, windows: [toplevel] }]
    property var windows: []              // windows mode: the chosen app's toplevels, MRU first
    property int windowsOf: 0             // windows mode: index in `apps` of the app shown

    function step(d) {
        if (!showing) {
            apps = Windows.byApp()
            if (apps.length === 0) return
            mode = "apps"
            current = 0
            showing = true
        } else if (mode === "windows") {
            // Cmd+Tab in the windows view: back to the app icons, on the same app
            mode = "apps"
            current = windowsOf
            return
        }
        const n = mode === "apps" ? apps.length : windows.length
        current = (current + d + n) % n
    }
    function showWindows(d) {
        if (!showing) {
            // closed: the focused app's windows, starting at its next window
            apps = Windows.byApp()
            if (apps.length === 0) return
            windows = apps[0].windows
            windowsOf = 0
            mode = "windows"
            current = windows.length > 1 ? 1 : 0
            showing = true
            return
        }
        if (mode === "apps") {
            windows = apps[current]?.windows ?? []
            windowsOf = current
            mode = "windows"
            current = 0
            return
        }
        current = (current + d + windows.length) % windows.length
    }
    function commit() {
        if (!showing) return
        showing = false
        const t = mode === "apps" ? apps[current]?.windows[0] : windows[current]
        if (t) Windows.focus(t)
    }
    function cancel() { showing = false }

    // hover selects only when the mouse really moves, not when the switcher opens under it
    property point lastMouse: Qt.point(-1, -1)
    onShowingChanged: lastMouse = Qt.point(-1, -1)
    function hovered(item, mouse, i) {
        const p = item.mapToItem(null, mouse.x, mouse.y)
        if (p.x === lastMouse.x && p.y === lastMouse.y) return
        const first = lastMouse.x < 0
        lastMouse = p
        if (!first) current = i
    }

    GlobalShortcut { appid: "quickshell"; name: "switcher-next"; description: "App switcher: next"; onPressed: root.step(1) }
    GlobalShortcut { appid: "quickshell"; name: "switcher-prev"; description: "App switcher: previous"; onPressed: root.step(-1) }
    GlobalShortcut { appid: "quickshell"; name: "switcher-windows"; description: "App switcher: windows of the app"; onPressed: root.showWindows(1) }
    GlobalShortcut { appid: "quickshell"; name: "switcher-windows-prev"; description: "App switcher: windows, backwards"; onPressed: root.showWindows(-1) }
    GlobalShortcut { appid: "quickshell"; name: "switcher-commit"; description: "App switcher: switch"; onPressed: root.commit() }

    IpcHandler {
        target: "switcher"
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function appWindows(): void { root.showWindows(1) }
        function commit(): void { root.commit() }
        function cancel(): void { root.cancel() }
    }

    // ---- window ----------------------------------------------------------------------------
    PanelWindow {
        screen: Screens.focused
        visible: root.showing
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-switcher"
        // take the keyboard while open, to see Alt (= Cmd) being let go
        WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: root.cancel() }

        Item {
            anchors.fill: parent
            focus: root.showing
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr || !(event.modifiers & Qt.AltModifier)) {
                    event.accepted = true
                    root.commit()
                }
            }
            Keys.onPressed: event => {
                event.accepted = true
                if (event.key === Qt.Key_Escape) root.cancel()
                else if (event.key === Qt.Key_Right) root.mode === "apps" ? root.step(1) : root.showWindows(1)
                else if (event.key === Qt.Key_Left) root.mode === "apps" ? root.step(-1) : root.showWindows(-1)
                else if (event.key === Qt.Key_Down && root.mode === "apps") root.showWindows(1)
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.commit()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, (root.mode === "apps" ? appRow.implicitWidth : winRow.implicitWidth) + 2 * 18)
            height: (root.mode === "apps" ? appRow.implicitHeight : winRow.implicitHeight) + 2 * 18
            color: Theme.panel
            border { color: Theme.hairline; width: 1 }
            radius: 2
            clip: true

            // apps: one icon each
            Row {
                id: appRow
                visible: root.mode === "apps"
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: root.mode === "apps" ? root.apps : []
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.current
                        width: 84; height: 84

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: cell.selected ? Theme.hover : "transparent"
                            border { color: cell.selected ? Theme.hairline : "transparent"; width: 1 }
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            implicitSize: 60
                            icon: cell.modelData.icon
                        }
                        // small dots under the icon: how many windows the app has (up to 4)
                        Row {
                            visible: cell.modelData.windows.length > 1
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                            spacing: 3
                            Repeater {
                                model: Math.min(4, cell.modelData.windows.length)
                                Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.inkDim }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => root.hovered(parent, mouse, cell.index)
                            onClicked: { root.current = cell.index; root.commit() }
                        }
                    }
                }
            }

            // windows of one app: a small live picture of each, with its title
            Row {
                id: winRow
                visible: root.mode === "windows"
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: root.mode === "windows" ? root.windows : []
                    delegate: Item {
                        id: wcell
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.current
                        width: 240; height: 190

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: wcell.selected ? Theme.hover : "transparent"
                            border { color: wcell.selected ? Theme.hairline : "transparent"; width: 1 }
                        }
                        ScreencopyView {
                            id: shot
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
                            captureSource: wcell.modelData.wayland
                            live: false
                            constraintSize: Qt.size(220, 140)
                            width: 220; height: 140
                        }
                        Rectangle {      // hairline frame around the picture
                            anchors.fill: shot
                            color: "transparent"
                            border { color: Theme.hairline; width: 1 }
                        }
                        Text {
                            anchors { top: shot.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
                            horizontalAlignment: Text.AlignHCenter
                            text: wcell.modelData.title
                            elide: Text.ElideRight
                            color: wcell.selected ? Theme.ink : Theme.inkDim
                            font: Theme.textSmall
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => root.hovered(parent, mouse, wcell.index)
                            onClicked: { root.current = wcell.index; root.commit() }
                        }
                    }
                }
            }
        }
    }
}

// Desktops I..IV, plus V while the TV is plugged in (V is the TV; see hypr/desktops.lua).
// Click or scroll to switch; both go through desktops.lua so they behave like Opt+1..5 / Opt+P/N.
// Focused: ink with a thin underline. Has windows: dim ink. Empty: faint.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
    id: root
    property var screen
    // keep in sync with hypr/desktops.lua (M.tv, M.tv_desktop)
    readonly property bool tvPresent: Hyprland.monitors.values.some(m => (m.description ?? "").startsWith("Sony SONY TV"))
    readonly property int count: tvPresent ? 5 : 4
    spacing: 2

    function desktops(call) {
        Quickshell.execDetached(["hyprctl", "eval", `require("desktops").${call}`])
    }

    function roman(n) {
        return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][n - 1] ?? String(n)
    }

    Repeater {
        model: root.count

        Item {
            id: cell
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
            readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0
            readonly property bool urgent: ws?.urgent ?? false

            implicitWidth: label.implicitWidth + 14
            implicitHeight: Theme.barHeight

            Rectangle {   // hover wash
                anchors { fill: parent; topMargin: 5; bottomMargin: 5 }
                radius: Theme.radius
                color: mouse.containsMouse && !cell.focused ? Theme.hover : "transparent"
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: root.roman(cell.wsId)
                font: Theme.textCaps
                color: cell.urgent ? Theme.urgent
                     : cell.focused ? Theme.ink
                     : cell.occupied ? Theme.inkDim : Theme.inkFaint
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {   // underline on the focused desktop
                anchors { horizontalCenter: parent.horizontalCenter; top: label.bottom; topMargin: 1 }
                height: 1
                width: cell.focused ? label.implicitWidth : 0
                color: Theme.ink
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.desktops(`go(${cell.wsId})`)
            }
        }
    }

    WheelHandler {
        onWheel: event => root.desktops(event.angleDelta.y < 0 ? "step(1)" : "step(-1)")
    }
}

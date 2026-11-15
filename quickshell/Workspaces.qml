// Desktops I..V, always shown (like KDE's fixed desktops). Click or scroll to switch.
// Focused: ink with a thin underline. Has windows: dim ink. Empty: faint.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
    id: root
    property var screen
    property int count: 5   // keep in sync with `desktops` in keys/remap.toml
    spacing: 2

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
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${cell.wsId} })`)
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            const cur = Hyprland.focusedWorkspace?.id ?? 1
            const next = event.angleDelta.y < 0 ? cur % root.count + 1 : (cur + root.count - 2) % root.count + 1
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${next} })`)
        }
    }
}

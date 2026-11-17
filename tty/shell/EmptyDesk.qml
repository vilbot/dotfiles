// An empty desktop is a terminal-like prompt: the launcher, where a terminal's prompt would be
// (foot's size and padding: Hack 16px, 10x6), with its results listed below like output. You can
// type straight away; it goes as soon as a window is on the desktop. Same launcher as Cmd+Space
// (Launcher.qml, LauncherInput.qml), so the same keys and searches (Files ~/, nvim ~/, ...).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: desk
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    readonly property bool empty: (Hyprland.focusedWorkspace?.toplevels?.values?.length ?? 1) === 0
    readonly property bool active: empty && !Launcher.open
    visible: active
    onActiveChanged: { Launcher.desk = active; if (active) { Launcher.query = ""; field.forceActiveFocus() } }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Normal   // under the bar
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tty-launcher"   // mackeys: the launcher's own Ctrl keys
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property font font: Qt.font({ family: "Hack", pixelSize: 16 })
    readonly property font bold: Qt.font({ family: "Hack", pixelSize: 16, bold: true })
    readonly property int line: Math.round(19 * 96 / 72)   // foot's line-height (19pt)
    FontMetrics { id: metrics; font: desk.font }

    Item {
        anchors { fill: parent; leftMargin: 10; topMargin: 6 }

        Row {
            id: prompt
            height: desk.line
            spacing: metrics.advanceWidth(" ")
            Text { text: ">"; font: desk.bold; color: Colors.base0E; anchors.verticalCenter: parent.verticalCenter }
            LauncherInput {
                id: field
                width: desk.width - 40
                anchors.verticalCenter: parent.verticalCenter
                font: desk.font
                cursorWidth: metrics.advanceWidth("M")
                onCancelled: Launcher.query = ""
            }
        }

        ListView {   // the results, like a command's output under its prompt
            anchors { top: prompt.bottom; left: parent.left }
            width: Math.min(desk.width - 20, 900)
            height: desk.line * Math.min(15, count)
            model: Launcher.results
            currentIndex: Launcher.current
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool picked: index === Launcher.current
                width: ListView.view.width
                height: desk.line
                color: picked ? Colors.base02 : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - detail.width - 26   // long names (a page's title) stop short of the detail
                    elide: Text.ElideRight
                    text: (Launcher.favorites.includes(row.modelData.id) ? "* " : "  ") + row.modelData.name
                    font: row.picked ? desk.bold : desk.font
                    color: row.modelData.isDir ? Colors.base0D : row.picked ? Colors.base07 : Colors.base06
                }
                Text {
                    id: detail
                    readonly property bool asking: Launcher.confirming === row.modelData.id
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: asking ? "⏎ again to confirm" : row.modelData.detail
                    font: asking ? desk.bold : desk.font
                    color: asking ? Colors.base08 : Colors.base04
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: Launcher.current = row.index
                    onClicked: Launcher.run(row.index)
                }
            }
        }
    }
}

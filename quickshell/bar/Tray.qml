// System tray (KDE Connect, Discord, ...). Left click activates, right click opens the menu.
// Items listed in `hidden` (tray item ids) aren't shown: Vicinae (Cmd+Space opens it), Steam.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services

RowLayout {
    id: root
    required property var barWindow
    spacing: 8
    readonly property var hidden: ["vicinae", "steam"]
    visible: items.count > 0     // no empty gap in the bar

    Repeater {
        id: items
        model: SystemTray.items.values.filter(i => !root.hidden.includes(i.id))

        IconImage {
            id: icon
            required property SystemTrayItem modelData
            implicitSize: 16
            source: modelData.icon

            QsMenuAnchor {
                id: menu
                menu: icon.modelData.menu
                anchor.window: root.barWindow
                anchor.rect: {
                    const p = icon.mapToItem(null, 0, 0)
                    return Qt.rect(p.x, root.barWindow.height, icon.width, 1)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const item = icon.modelData
                    if (mouse.button === Qt.MiddleButton) item.secondaryActivate()
                    else if (mouse.button === Qt.RightButton || item.onlyMenu) { if (item.hasMenu) menu.open() }
                    else item.activate()
                }
                onWheel: wheel => icon.modelData.scroll(wheel.angleDelta.y / 120, false)
            }
        }
    }
}

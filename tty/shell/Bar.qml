// The bar along the top of None (what it shows: BarContent.qml).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Ui.barHeight
    color: Colors.base00
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tty-bar"

    BarContent {
        anchors.fill: parent
        here: Hyprland.focusedMonitor?.name === bar.screen.name
        // never on the login screen, which has no launcher
        launching: !Ui.greeter && Launcher.open && here
        minimal: Ui.greeter
    }
}

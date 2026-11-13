// Top bar, styled like a gallery wall label: desktops + window title on the left, status on the right.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-bar"   // hypr/hyprland.lua blurs this layer
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.wall

    // hairline under the bar
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.hairline
    }

    RowLayout {
        anchors { fill: parent; leftMargin: Theme.barPadding; rightMargin: Theme.barPadding }
        spacing: Theme.gap

        Workspaces { screen: bar.screen }
        WindowTitle { Layout.fillWidth: true }

        KeyboardLayout {}
        Volume {}
        Tray { barWindow: bar }
        Clock {}
    }
}

// Top bar, styled like a gallery wall label: desktops + window title on the left, status on the right.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services

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

        // Nested layouts (Workspaces, Tray) fill width by default in Qt; keep them at their size so
        // only the window title takes the free space.
        Workspaces { Layout.fillWidth: false }
        // preferredWidth 0: a long title takes only the leftover space (and elides) instead of
        // squeezing the items on the right
        WindowTitle { Layout.fillWidth: true; Layout.preferredWidth: 0 }

        KeyboardLayout {}
        Volume {}
        Tray { barWindow: bar; Layout.fillWidth: false }
        ControlButton {}
        Clock {}
    }
}

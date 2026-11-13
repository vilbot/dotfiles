// Control center (like the Mac's): sound, display, network, Bluetooth, and links to the full
// settings. Opens from the switches icon in the bar, or `qs ipc call controlcenter toggle`.
// Click outside or press Esc to close.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    readonly property int panelWidth: 360
    readonly property var screenNow: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                                     ?? Quickshell.screens[0]

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { Panels.toggleControl() }
        function open(): void { if (!Panels.controlOpen) Panels.toggleControl() }
        function close(): void { Panels.controlOpen = false }
    }

    PanelWindow {
        screen: root.screenNow
        visible: Panels.controlOpen

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-controlcenter"
        WlrLayershell.keyboardFocus: Panels.controlOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal      // below the bar
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // click outside the panel closes it
        MouseArea { anchors.fill: parent; onClicked: Panels.controlOpen = false }
        Item {
            anchors.fill: parent
            focus: Panels.controlOpen
            Keys.onEscapePressed: Panels.controlOpen = false
        }

        Rectangle {
            anchors { top: parent.top; right: parent.right; margins: 10 }
            width: root.panelWidth
            height: content.implicitHeight + 2 * 18
            color: Theme.panel
            border { color: Theme.hairline; width: 1 }
            radius: 2
            MouseArea { anchors.fill: parent }   // clicks on the panel don't close it

            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 14

                CcSound { Layout.fillWidth: true }
                Rule {}
                CcDisplay { id: display; Layout.fillWidth: true }
                Rule { visible: display.visible }
                CcNetwork { Layout.fillWidth: true; open: Panels.controlOpen }
                Rule {}
                CcBluetooth { id: bt; Layout.fillWidth: true }
                Rule { visible: bt.visible }

                RowLayout {
                    Layout.fillWidth: true
                    LinkText {
                        text: "Settings…"
                        onClicked: { Panels.controlOpen = false; Panels.settingsOpen = true }
                    }
                    Item { Layout.fillWidth: true }
                    LinkText {
                        text: "System Settings…"
                        onClicked: { Panels.controlOpen = false; Quickshell.execDetached(["systemsettings"]) }
                    }
                }
            }
        }
    }

    component Rule: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }
}

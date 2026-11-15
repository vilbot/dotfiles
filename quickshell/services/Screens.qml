pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    // where panels and popups open: the monitor with keyboard focus
    readonly property var focused: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
}

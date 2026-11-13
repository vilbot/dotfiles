// Title of the focused window, in italic like a work's title on a label.
import QtQuick
import Quickshell.Hyprland

Text {
    text: Hyprland.activeToplevel?.title ?? ""
    elide: Text.ElideRight
    color: Theme.inkDim
    font: Theme.textItalic
}

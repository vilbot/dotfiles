// An app's icon by theme name or file path, with a generic one when it has none.
import QtQuick
import Quickshell
import Quickshell.Widgets

IconImage {
    property string icon: ""
    source: icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon || "application-x-executable", "application-x-executable")
}

// Wallpaper drawn by Quickshell on the background layer (no separate wallpaper daemon).
// The image fills the screen and is cropped to fit, never stretched.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"   // only visible while the image loads

    Image {
        anchors.fill: parent
        source: Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        // decode at screen size, not the image's full resolution
        sourceSize { width: parent.width; height: parent.height }
    }
}

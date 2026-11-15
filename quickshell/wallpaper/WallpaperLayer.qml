// Wallpaper drawn by Quickshell on the background layer (no separate wallpaper daemon).
// The picture fills the screen and is cropped to fit, never stretched. What to show (one picture
// or a slideshow) comes from services/Wallpaper.qml; a new picture comes in with its transition:
// fade, slide (in from the right, over the old one), zoom (settles from slightly larger while
// fading in) or none. Two Image items take turns being the front one.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"   // only visible before the first picture has loaded

    readonly property string want: Wallpaper.current
        ? "file://" + Wallpaper.current.split("/").map(encodeURIComponent).join("/") : ""
    property Image front: a
    property bool first: true      // the first picture just appears

    onWantChanged: swap()
    Component.onCompleted: swap()

    // load the wanted picture into the back image; show() runs once it's decoded
    function swap() {
        if (!want || String(front.source) === want) return
        const back = front === a ? b : a
        back.source = want
        if (back.status === Image.Ready) show(back)
    }
    function show(next) {
        anim.stop()
        const prev = front
        const t = first ? "none" : Wallpaper.transition
        first = false
        prev.z = 0; next.z = 1
        next.opacity = t === "fade" || t === "zoom" ? 0 : 1
        next.x = t === "slide" ? width : 0
        next.scale = t === "zoom" ? 1.06 : 1
        front = next
        anim.prev = prev
        if (t === "none") prev.source = ""
        else anim.start()
    }
    ParallelAnimation {
        id: anim
        property Image prev
        NumberAnimation { target: win.front; property: "opacity"; to: 1; duration: 1000; easing.type: Easing.InOutQuad }
        NumberAnimation { target: win.front; property: "x"; to: 0; duration: 900; easing.type: Easing.InOutCubic }
        NumberAnimation { target: win.front; property: "scale"; to: 1; duration: 1400; easing.type: Easing.OutCubic }
        onFinished: if (prev && prev !== win.front) prev.source = ""   // free the old picture
    }

    Image {
        id: a
        width: win.width
        height: win.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        cache: false
        // decode at screen size, not the picture's full resolution
        sourceSize { width: win.width; height: win.height }
        onStatusChanged: if (status === Image.Ready && String(source) === win.want && win.front !== a) win.show(a)
    }
    Image {
        id: b
        width: win.width
        height: win.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        cache: false
        // decode at screen size, not the picture's full resolution
        sourceSize { width: win.width; height: win.height }
        onStatusChanged: if (status === Image.Ready && String(source) === win.want && win.front !== b) win.show(b)
    }
}

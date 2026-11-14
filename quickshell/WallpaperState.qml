// What the wallpaper shows (Wallpaper.qml draws it; the settings window's Wallpaper page edits it).
// One path: a picture file is the wallpaper; a folder makes a slideshow of the pictures in it, in
// name order, changing every `interval` seconds with the chosen transition. Which picture is up is
// worked out from the clock, so the slideshow carries on where it was after a restart.
// Saved in ~/.local/state/quickshell/wallpaper.json (outside this folder: Quickshell restarts when
// a file it read in its own folder changes).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // settings
    readonly property string path: cfg.path
    readonly property int interval: cfg.interval          // seconds
    readonly property string transition: cfg.transition   // "none" | "fade" | "slide" | "zoom"
    function setPath(p) { cfg.path = p.trim() }
    function setInterval(s) { cfg.interval = s }
    function setTransition(t) { cfg.transition = t }

    // `qs ipc call wallpaper set ~/Pictures/some-folder`
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { root.setPath(path) }
        function get(): string { return root.path }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper.json"
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: cfg
            property string path: "~/Pictures/wallpaper.jpg"
            property int interval: 1800
            property string transition: "fade"
        }
    }

    // pictures
    readonly property string expanded: path.replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
    property var images: []        // full paths: the file, or the folder's pictures
    property bool isFolder: false
    property bool found: true
    property int index: 0
    readonly property string current: images.length ? images[index % images.length] : ""

    onExpandedChanged: rescan()
    onIntervalChanged: pick()
    // (the command gets the path here, at each start: a binding on it would still hold the old
    // path when this runs from onExpandedChanged)
    function rescan() {
        lister.running = false
        lister.command = ["sh", "-c", listScript, "sh", expanded]
        lister.running = true
    }
    readonly property string listScript:
        'p="$1"; if [ -d "$p" ]; then echo DIR; find "$p" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" ' +
        '-o -iname "*.png" -o -iname "*.webp" -o -iname "*.avif" -o -iname "*.bmp" \\) | sort; ' +
        'elif [ -f "$p" ]; then echo FILE; echo "$p"; else echo NONE; fi'

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l)
                root.found = lines[0] !== "NONE"
                root.isFolder = lines[0] === "DIR"
                root.images = lines.slice(1)
                root.pick()
            }
        }
    }

    // slideshow: picture number = how many intervals have passed since 1970; wake up at the next one
    function pick() {
        if (!isFolder || images.length < 2) { index = 0; tick.stop(); return }
        const now = Date.now() / 1000
        index = Math.floor(now / interval) % images.length
        tick.interval = Math.ceil((interval - now % interval) * 1000) + 50
        tick.restart()
    }
    Timer { id: tick; onTriggered: root.rescan() }   // rescan: picks up pictures added meanwhile
}

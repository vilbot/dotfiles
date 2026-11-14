// Shared look for every Quickshell component. Colors come from Colors.qml (generated
// from theme/gruver16.yaml); edit roles and sizes here.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    // Gallery look: the bar is a warm off-white "wall label" over the painting, with ink-colored
    // serif type (in dark mode: charcoal with warm light type). These are hand-picked (not
    // gruver16, which is for dark editors/terminals); Colors.<baseXX> is still available for
    // anything that should match the terminal theme.
    readonly property color hairline:  dark ? Qt.rgba(0.925, 0.902, 0.855, 0.16) : Qt.rgba(0.165, 0.153, 0.137, 0.15)
    readonly property color ink:       dark ? "#ece6da" : "#2a2723"   // main text
    readonly property color inkDim:    dark ? "#a8a093" : "#6b655c"   // secondary text
    readonly property color inkFaint:  dark ? "#6f695f" : "#a39d92"   // empty / inactive
    readonly property color hover:     dark ? Qt.rgba(0.925, 0.902, 0.855, 0.08) : Qt.rgba(0.165, 0.153, 0.137, 0.07)
    readonly property color urgent:    dark ? "#d77a5e" : "#a2462e"   // muted vermilion
    readonly property color paper:     dark ? "#22201d" : "#f3efe6"   // opaque wall: windows, slider handles
    // See-through so the liquid glass under them shows (hyprglass, set up in hypr/hyprland.lua):
    readonly property color wall:      Qt.rgba(paper.r, paper.g, paper.b, 0.30)   // the bar
    readonly property color panel:     Qt.rgba(paper.r, paper.g, paper.b, 0.40)   // pop-over panels
    readonly property color card:      Qt.rgba(paper.r, paper.g, paper.b, 0.55)   // Opt+? sheet (> 0.5: hyprglass mask)

    // Dark / light follows the desktop's color scheme (gsettings color-scheme, set by
    // hypr/appearance.sh on F6), so the bar switches together with GTK, KDE apps and Chrome.
    property bool dark: false
    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector { onStreamFinished: theme.dark = text.includes("prefer-dark") }
    }
    Process {
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        stdout: SplitParser { onRead: line => theme.dark = line.includes("prefer-dark") }
    }

    // type: Liberation Serif (Times-like, comes with the system).
    // Use `font: Theme.text` / textItalic / textCaps; don't set family/size per component.
    readonly property string fontFamily: "Liberation Serif"
    readonly property int fontSize: 15
    readonly property font text:       Qt.font({ family: fontFamily, pixelSize: fontSize })
    readonly property font textItalic: Qt.font({ family: fontFamily, pixelSize: fontSize, italic: true })
    // letter-spaced capitals, like a museum label (numerals, "US")
    readonly property font textCaps:   Qt.font({ family: fontFamily, pixelSize: fontSize - 1, letterSpacing: 1.5 })
    readonly property font textSmall:  Qt.font({ family: fontFamily, pixelSize: fontSize - 2, italic: true })
    readonly property font heading:    Qt.font({ family: fontFamily, pixelSize: 24, italic: true })

    // wallpaper: WallpaperState.qml (set in the settings window)

    // bar
    readonly property int barHeight: 32
    readonly property int barPadding: 18    // left/right inner padding
    readonly property int gap: 22           // between bar sections
    readonly property int radius: 4
}

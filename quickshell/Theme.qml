// Shared look for every Quickshell component. Colors come from Colors.qml (generated
// from theme/gruver16.yaml); edit roles and sizes here.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Gallery look: the bar is a warm off-white "wall label" over the painting, with ink-colored
    // serif type. These are hand-picked (not gruver16, which is for dark editors/terminals);
    // Colors.<baseXX> is still available for anything that should match the terminal theme.
    readonly property color wall:      Qt.rgba(0.953, 0.937, 0.902, 0.88)   // #f3efe6, translucent
    readonly property color hairline:  Qt.rgba(0.165, 0.153, 0.137, 0.15)
    readonly property color ink:       "#2a2723"   // main text
    readonly property color inkDim:    "#6b655c"   // secondary text
    readonly property color inkFaint:  "#a39d92"   // empty / inactive
    readonly property color hover:     Qt.rgba(0.165, 0.153, 0.137, 0.07)
    readonly property color urgent:    "#a2462e"   // muted vermilion
    readonly property color paper:     "#f3efe6"   // opaque wall: windows, slider handles
    readonly property color panel:     Qt.rgba(0.953, 0.937, 0.902, 0.94)   // pop-over panels

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

    // wallpaper (not in the repo; drop any painting there)
    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/Pictures/wallpaper.jpg"

    // bar
    readonly property int barHeight: 32
    readonly property int barPadding: 18    // left/right inner padding
    readonly property int gap: 22           // between bar sections
    readonly property int radius: 4
}

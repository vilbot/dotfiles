// The Settings app's look: None's colours (Colors, the current theme) by role, Hack, sizes.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string family: "Hack"
    readonly property font font: Qt.font({ family: family, pixelSize: 14 })
    readonly property font bold: Qt.font({ family: family, pixelSize: 14, bold: true })
    readonly property font small: Qt.font({ family: family, pixelSize: 12 })
    readonly property font title: Qt.font({ family: family, pixelSize: 20, bold: true })
    readonly property font heading: Qt.font({ family: family, pixelSize: 12, bold: true, letterSpacing: 1.5 })

    readonly property color bg: Colors.base00
    readonly property color raised: Colors.base01       // the row under the mouse / picked
    readonly property color line: Colors.base02         // borders, tracks
    readonly property color faint: Colors.base03
    readonly property color dim: Colors.base04
    readonly property color text: Colors.base06
    readonly property color strong: Colors.base07
    readonly property color accent: Colors.base0E       // yellow: what's picked, what's changing
    readonly property color link: Colors.base0D
    readonly property color good: Colors.base0B
    readonly property color bad: Colors.base08

    readonly property int row: 34
    readonly property int pad: 28                       // the page's side margins
    readonly property int quick: 120                    // ms, every transition
}

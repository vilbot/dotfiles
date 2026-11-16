// Sizes and fonts every part of None's shell shares: one monospace size, a terminal's look.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property font font: Qt.font({ family: "Hack", pixelSize: 14 })
    readonly property font bold: Qt.font({ family: "Hack", pixelSize: 14, bold: true })
    readonly property int barHeight: 28
    readonly property int row: 24            // one line in a list
    readonly property int centerWidth: 640   // the app name / launcher in the middle of the bar
    readonly property int quick: 140         // ms, every transition
    readonly property bool greeter: Quickshell.env("TTY_GREETER") === "1"   // the login screen
}

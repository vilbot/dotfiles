// Control center: monitor brightness (DDC/CI via ddcutil) and night light (hyprsunset).
// Each row hides itself when it can't work: brightness needs DDC/CI turned on in the monitor's
// own menu, night light needs the hyprsunset package.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

ColumnLayout {
    id: root
    spacing: 8
    visible: brightness >= 0 || hasSunset

    property int brightness: -1          // 0..100, -1 = no DDC
    property int pending: -1             // value waiting to be sent
    property bool hasSunset: false
    property bool nightLight: false
    readonly property int nightTemperature: 4000   // Kelvin

    Text { text: "DISPLAY"; color: Theme.inkFaint; font: Theme.textCaps }

    // ---- brightness -----------------------------------------------------------------------
    // "VCP 10 C 50 100" = current 50, max 100
    Process {
        id: probe
        running: true
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/VCP 10 C (\d+) (\d+)/)
                if (m) root.brightness = Math.round(100 * Number(m[1]) / Number(m[2]))
            }
        }
    }
    Process {
        id: setter
        onExited: if (root.pending >= 0) send.restart()
    }
    Timer {          // ddcutil is slow (~0.1 s per write): send at most one value at a time
        id: send
        interval: 80
        onTriggered: {
            if (root.pending < 0 || setter.running) return
            setter.command = ["ddcutil", "setvcp", "10", String(root.pending), "--noverify"]
            root.pending = -1
            setter.running = true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.brightness >= 0
        spacing: 10
        IconImage { implicitSize: 16; source: Quickshell.iconPath("brightness-high-symbolic", "display-brightness-symbolic") }
        Slider {
            Layout.fillWidth: true
            value: root.brightness / 100
            onMoved: v => { root.brightness = Math.round(v * 100); root.pending = root.brightness; send.restart() }
        }
        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: root.brightness + "%"
            color: Theme.inkDim
            font: Theme.text
        }
    }

    // ---- night light ----------------------------------------------------------------------
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: code => root.hasSunset = code === 0
    }
    Process {        // runs while night light is on; stopping it restores normal colors
        running: root.nightLight
        command: ["hyprsunset", "-t", String(root.nightTemperature)]
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.hasSunset
        spacing: 10
        IconImage { implicitSize: 16; source: Quickshell.iconPath("redshift-status-on", "weather-clear-night-symbolic") }
        Text { Layout.fillWidth: true; text: "Night light"; color: Theme.ink; font: Theme.text }
        Toggle { checked: root.nightLight; onToggled: v => root.nightLight = v }
    }
}

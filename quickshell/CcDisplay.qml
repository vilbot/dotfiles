// Control center: brightness and night light.
// Brightness goes to the monitor itself over DDC/CI (ddcutil) when the monitor answers; otherwise
// (DDC/CI off in its menu, or a driver that can't reach it, like NVIDIA's open driver over
// DisplayPort) the screen is dimmed in software with hyprsunset's gamma. One hyprsunset runs
// while the shell runs and does both dimming and night light (`hyprctl hyprsunset ...`).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

ColumnLayout {
    id: root
    spacing: 8
    visible: hasDdc || hasSunset

    property int brightness: -1          // monitor brightness 0..100 over DDC, -1 = no DDC
    readonly property bool hasDdc: brightness >= 0
    property int dim: 100                // software brightness (hyprsunset gamma %), without DDC
    readonly property int dimMin: 20     // never darker than this (the screen stays readable)
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

    // F1 / F2 (keys/keymap.toml: brightness.down/up): `qs ipc call brightness down|up`
    function step(d) {
        if (hasDdc) {
            brightness = Math.max(0, Math.min(100, brightness + d))
            pending = brightness
            send.restart()
        } else if (hasSunset) {
            dim = Math.max(dimMin, Math.min(100, dim + d))
        }
    }
    IpcHandler {
        target: "brightness"
        function up(): void { root.step(10) }
        function down(): void { root.step(-10) }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.hasDdc || root.hasSunset
        spacing: 10
        SymbolIcon { implicitSize: 16; source: Quickshell.iconPath("brightness-high-symbolic", "display-brightness-symbolic") }
        Slider {
            Layout.fillWidth: true
            value: (root.hasDdc ? root.brightness : root.dim) / 100
            onMoved: v => {
                if (root.hasDdc) { root.brightness = Math.round(v * 100); root.pending = root.brightness; send.restart() }
                else root.dim = Math.max(root.dimMin, Math.round(v * 100))
            }
        }
        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: (root.hasDdc ? root.brightness : root.dim) + "%"
            color: Theme.inkDim
            font: Theme.text
        }
    }

    // ---- hyprsunset: night light + software dimming -------------------------------------------
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: code => root.hasSunset = code === 0
    }
    Process {        // starts with normal colors; stopping it (shell restart) restores them
        running: root.hasSunset
        command: ["hyprsunset", "--identity"]
    }
    function sunset(args) { Quickshell.execDetached(["hyprctl", "hyprsunset"].concat(args)) }
    onDimChanged: sunset(["gamma", String(dim)])
    onNightLightChanged: {
        if (nightLight) sunset(["temperature", String(nightTemperature)])
        else { sunset(["identity"]); sunset(["gamma", String(dim)]) }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.hasSunset
        spacing: 10
        SymbolIcon { implicitSize: 16; source: Quickshell.iconPath("redshift-status-on", "weather-clear-night-symbolic") }
        Text { Layout.fillWidth: true; text: "Night light"; color: Theme.ink; font: Theme.text }
        Toggle { checked: root.nightLight; onToggled: v => root.nightLight = v }
    }
}

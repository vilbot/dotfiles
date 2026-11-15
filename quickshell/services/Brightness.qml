// Screen brightness and night light.
// Brightness goes to the monitor over DDC/CI (ddcutil) when it answers. The Samsung doesn't on
// NVIDIA's open driver, so then the screen is dimmed with hyprsunset's gamma instead. One
// hyprsunset runs with the shell and does both dimming and night light.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool available: hasDdc || hasSunset
    readonly property int value: hasDdc ? ddc : dim       // 0..100
    property bool nightLight: false

    property int ddc: -1                 // over DDC/CI, -1 = the monitor doesn't answer
    readonly property bool hasDdc: ddc >= 0
    property int dim: 100                // hyprsunset gamma, without DDC
    readonly property int dimMin: 20     // the screen stays readable
    property bool hasSunset: false
    readonly property int nightTemperature: 4000

    function set(v) {
        v = Math.round(Math.max(0, Math.min(100, v)))
        if (hasDdc) { ddc = v; pending = v; send.restart() }
        else if (hasSunset) dim = Math.max(dimMin, v)
    }
    function step(d) { set(value + d) }

    // F1 / F2 (brightness.down/up in keys/remap.toml)
    IpcHandler {
        target: "brightness"
        function up(): void { root.step(10) }
        function down(): void { root.step(-10) }
    }

    // ---- DDC/CI: "VCP 10 C 50 100" = 50 of 100 ----
    Process {
        running: true
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/VCP 10 C (\d+) (\d+)/)
                if (m) root.ddc = Math.round(100 * Number(m[1]) / Number(m[2]))
            }
        }
    }
    property int pending: -1
    Process { id: setter; onExited: if (root.pending >= 0) send.restart() }
    Timer {          // a write takes ~0.1 s: one at a time, the latest value
        id: send
        interval: 80
        onTriggered: {
            if (root.pending < 0 || setter.running) return
            setter.command = ["ddcutil", "setvcp", "10", String(root.pending), "--noverify"]
            root.pending = -1
            setter.running = true
        }
    }

    // ---- hyprsunset ----
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: code => root.hasSunset = code === 0
    }
    // Starts with normal colors; when it stops (shell restart) they come back. One left behind by
    // a shell that crashed would keep the socket, so it goes first.
    Process {
        running: root.hasSunset
        command: ["sh", "-c", "pkill -x hyprsunset; exec hyprsunset --identity"]
    }
    function sunset(args) { Quickshell.execDetached(["hyprctl", "hyprsunset"].concat(args)) }
    onDimChanged: sunset(["gamma", String(dim)])
    onNightLightChanged: {
        if (nightLight) sunset(["temperature", String(nightTemperature)])
        else { sunset(["identity"]); sunset(["gamma", String(dim)]) }
    }
}

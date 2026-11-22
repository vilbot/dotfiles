// Screen brightness (F1 / F2): over DDC/CI (ddcutil) when the monitor answers, else dimmed with
// hyprsunset's gamma (some monitors don't answer DDC, e.g. on NVIDIA). The corner shows it
// while it changes, like the volume.
//
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property int value: hasDdc ? ddc : dim       // 0..100
    property int ddc: -1                 // over DDC/CI, -1 = the monitor doesn't answer
    readonly property bool hasDdc: ddc >= 0
    property int dim: 100                // hyprsunset gamma, without DDC
    readonly property int dimMin: 20     // the screen stays readable
    property bool hasSunset: false

    property string text: ""             // "bri [#####-----]  50%" for the corner
    property bool shown: false

    function set(v) {
        v = Math.round(Math.max(0, Math.min(100, v)))
        if (hasDdc) { ddc = v; pending = v; send.restart() }
        else if (hasSunset) dim = Math.max(dimMin, v)
        text = "bri " + Status.bar(value / 100) + " " + String(value).padStart(3) + "%"
        shown = true
        hide.restart()
    }
    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }

    IpcHandler {
        target: "brightness"
        function up(): void { root.set(root.value + 10) }
        function down(): void { root.set(root.value - 10) }
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

    // ---- hyprsunset: starts with normal colours; one left by a crashed shell goes first ----
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: code => root.hasSunset = code === 0
    }
    Process {
        running: root.hasSunset
        command: ["sh", "-c", "pkill -x hyprsunset; exec hyprsunset --identity"]
    }
    onDimChanged: Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(dim)])
}

// Hyprland options the Settings app changes (the Keyboard & mouse page): their values now
// (hyprctl getoption), applied live while you change them (tty/options.lua, through
// `hyprctl eval`), and saved to tty/settings.json, which tty/hyprland.lua applies at start.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string file: Quickshell.shellDir + "/../settings.json"
    property var values: ({})          // option -> value now
    property var saved: ({})           // settings.json

    readonly property var keys: ["input:repeat_delay", "input:repeat_rate", "input:sensitivity", "input:accel_profile",
        "input:natural_scroll", "input:follow_mouse", "cursor:hide_on_key_press", "cursor:inactive_timeout"]

    function reload() { getter.running = true }
    Component.onCompleted: reload()
    Process {
        id: getter
        command: ["sh", "-c", root.keys.map(k => "hyprctl getoption " + k + " -j").join("; echo; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const chunk of text.split(/\n\s*\n/)) {
                    try {
                        const o = JSON.parse(chunk)
                        v[o.option] = o.str !== undefined ? (o.str === "[[EMPTY]]" ? "" : o.str)
                                    : o.bool ?? o.int ?? o.float
                    } catch (e) {}
                }
                root.values = v
            }
        }
    }
    FileView {
        id: savedFile
        path: root.file
        onLoaded: { try { root.saved = JSON.parse(text()) } catch (e) { root.saved = {} } }
    }

    function get(key) { return values[key] }
    function set(key, value) {
        const v = Object.assign({}, values); v[key] = value; values = v
        const s = Object.assign({}, saved); s[key] = value; saved = s
        pending[key] = value
        live.start()
        save.restart()
    }
    // a slider drag becomes one call every 50 ms, the file is written once it settles
    property var pending: ({})
    Timer {
        id: live
        interval: 50
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "eval", "NoneOptions.apply_json([==[" + JSON.stringify(root.pending) + "]==])"])
            root.pending = {}
        }
    }
    Timer {
        id: save
        interval: 400
        onTriggered: savedFile.setText(JSON.stringify(root.saved, Object.keys(root.saved).sort(), 4) + "\n")
    }
}

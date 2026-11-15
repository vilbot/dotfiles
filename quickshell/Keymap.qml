// Keyboard shortcuts model: the sheet mackeys writes from keys/remap.toml on every (re)load
// (~/.local/state/mackeys/keymap.json). Shown by the Opt+? sheet (Keybinds.qml) and edited on the
// settings window's Shortcuts page (ShortcutsPage.qml).
// apply() saves through `mackeys set`: it changes the keys in remap.toml (comments stay) and
// refuses keys that don't work, e.g. ones used twice. mackeys picks the file up within a second.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var model: ({})
    readonly property var groups: model.groups ?? []
    readonly property int desktops: model.desktops ?? 0
    // the sheet shows only actions that have a key
    readonly property var boundGroups: groups.map(g => ({ title: g.title, rows: g.rows.filter(r => r.keysLabel.length) }))
                                             .filter(g => g.rows.length)

    property bool busy: false
    property string error: ""          // what mackeys said, e.g. "the same keys are used twice (opt+f)"
    signal applied()

    // The dotfiles checkout: this folder's real location, one up.
    property string repo: ""
    Process {
        running: true
        command: ["sh", "-c", 'dirname "$(readlink -f "$1")"', "sh", Quickshell.shellDir]
        stdout: StdioCollector { onStreamFinished: root.repo = text.trim() }
    }
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
    FileView {
        path: root.state + "/mackeys/keymap.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.model = JSON.parse(text()) } catch (e) { console.warn("mackeys keymap.json:", e) }
        }
    }

    // changes: { action: ["opt+p", ...] }  ([] = no key)
    function apply(changes) {
        if (busy) return
        busy = true
        error = ""
        // first line: the exit code, then what mackeys said (its last line is the cause)
        proc.command = ["sh", "-c", 'out=$("$1/keys/daemon/target/release/mackeys" set "$1/keys/remap.toml" "$2" 2>&1); '
                        + 'printf "%s\\n%s" "$?" "$out"', "sh", root.repo, JSON.stringify(changes)]
        proc.running = true
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                root.busy = false
                if (lines[0] === "0") root.applied()
                else root.error = lines.slice(1).join("\n").trim().split("\n").pop().trim() || "couldn't save"
            }
        }
    }
}

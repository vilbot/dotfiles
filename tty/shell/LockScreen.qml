// The login screen, as a lock over None (and, in "lock" mode, the plain lock: only the password): you're logged in from boot (greetd starts tty/desktops),
// and None waits locked behind this form until your password opens it. Unlocking needs no new
// session, so there's no black between the form and the desktop. Logging out of None locks it
// again (session.exit and zsh's `logout`, tty/hyprland.lua and tty/zsh/.zshrc).
//
//   desktop   [None]  Hyprland  KDE      Up/Down or Tab: line; Left/Right or h/l: desktop
//   login     you                        Enter: next line; on the password: log in
//   password  ****
//
// None unlocks; Hyprland or KDE end None and tty/desktops starts that one (it reads the name from
// $XDG_RUNTIME_DIR/tty-next), then None, locked, after it. Locked or not is kept in
// $XDG_RUNTIME_DIR/tty-locked, so a reload of the shell doesn't lose it.
// Drawn like None's terminal (foot: Hack 12pt = 16px, 19pt lines, 10x6 padding) under the bar.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam

Scope {
    id: lock
    readonly property var desktops: ["None", "Hyprland", "KDE"]   // tty/desktops knows these names
    readonly property string run: Quickshell.env("XDG_RUNTIME_DIR")

    property bool locked: false
    // "login": the whole form (boot, logging out); "lock": only the password, for you, back to None
    property string mode: "login"
    readonly property bool locking: mode === "lock"
    property int field: 2                 // 0 desktop, 1 login, 2 password (always, locking)
    property int pick: 0
    property string login: Quickshell.env("USER") ?? ""
    property string password: ""
    property string message: ""
    property bool checking: false

    FileView { id: marker; path: lock.run + "/tty-locked"; blockLoading: true; printErrors: false }
    FileView { id: next; path: lock.run + "/tty-next"; printErrors: false }
    // the marker: "locked" (the login form; tty/desktops writes it at boot) or "lock"
    Component.onCompleted: {
        const m = marker.text().trim()
        mode = m === "lock" ? "lock" : "login"
        locked = m === "locked" || m === "lock"
    }

    function lockNow(how) {
        mode = how
        marker.setText(how === "lock" ? "lock" : "locked")
        login = Quickshell.env("USER") ?? ""
        field = 2; pick = 0; password = ""; message = ""
        locked = true
    }
    function submit() {
        if (checking) return
        checking = true
        message = ""
        pam.user = login
        if (!pam.start()) { checking = false; message = "can't check passwords (PAM)" }
    }
    function opened() {   // the password was right
        const to = locking ? "None" : desktops[pick]
        password = ""
        if (to === "None") {
            marker.setText("")
            locked = false
        } else {
            message = "starting " + to + "…"
            next.setText(to)
            Hyprland.dispatch("hl.dsp.exit()")
        }
    }

    PamContext {
        id: pam
        config: "system-auth"
        onPamMessage: {
            if (responseRequired) respond(lock.password)
            else if (messageIsError) lock.message = message
        }
        onCompleted: result => {
            lock.checking = false
            if (result === PamResult.Success) lock.opened()
            else { lock.password = ""; lock.message = "Login incorrect" }
        }
        onError: { lock.checking = false; lock.password = ""; lock.message = "Login incorrect" }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lock.lockNow("lock") }       // Ctrl+Cmd+Q, `lock`, before sleep
        function logout(): void { lock.lockNow("login") }    // Opt+Shift+Esc, `logout`
    }

    WlSessionLock {
        locked: lock.locked

        WlSessionLockSurface {
            color: Colors.base00

            BarContent {
                id: barRow
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: Ui.barHeight
                minimal: true
            }
            Rectangle { anchors { left: parent.left; right: parent.right; top: barRow.bottom } height: 1; color: Colors.base02 }

            // ---- the "terminal" ----
            Item {
                id: term
                anchors { left: parent.left; right: parent.right; top: barRow.bottom; bottom: parent.bottom }
                anchors { leftMargin: 10; topMargin: 6 }
                focus: true
                readonly property font font: Qt.font({ family: "Hack", pixelSize: 16 })
                readonly property font bold: Qt.font({ family: "Hack", pixelSize: 16, bold: true })
                readonly property real line: Math.round(19 * 96 / 72)
                FontMetrics { id: metrics; font: term.font }
                readonly property real cell: metrics.advanceWidth("M")

                Keys.onPressed: event => {
                    const k = event.key, ctrl = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)
                    const text = lock.field === 1 ? "login" : "password"
                    if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        if (lock.field === 2) lock.submit(); else lock.field++
                    } else if (lock.locking && [Qt.Key_Up, Qt.Key_Down, Qt.Key_Tab, Qt.Key_Backtab].includes(k)) {
                        // locked: only the password
                    } else if (k === Qt.Key_Up || k === Qt.Key_Backtab) {
                        lock.field = Math.max(0, lock.field - 1)
                    } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
                        lock.field = Math.min(2, lock.field + 1)
                    } else if (lock.field === 0) {
                        if (k === Qt.Key_Left || k === Qt.Key_H) lock.pick = (lock.pick + lock.desktops.length - 1) % lock.desktops.length
                        else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Space) lock.pick = (lock.pick + 1) % lock.desktops.length
                    } else if (k === Qt.Key_Backspace) {
                        lock[text] = lock[text].slice(0, -1)
                    } else if (ctrl && k === Qt.Key_U) {
                        lock[text] = ""
                    } else if (!ctrl && event.text.length === 1 && event.text >= " ") {
                        lock[text] += event.text
                    } else return
                    event.accepted = true
                }

                component Label: Text {
                    property bool on: false
                    font: on ? term.bold : term.font
                    color: on ? Colors.base0E : Colors.base04
                    width: term.cell * 10
                }
                Column {
                    y: term.line   // a blank first line, as a fresh terminal has its prompt there
                    Row {
                        visible: !lock.locking
                        height: term.line
                        Text { text: "  "; font: term.font }
                        Label { text: "desktop"; on: lock.field === 0 }
                        Repeater {
                            model: lock.desktops
                            Text {
                                required property string modelData
                                required property int index
                                readonly property bool picked: index === lock.pick
                                text: (picked ? "[" + modelData + "]" : " " + modelData + " ") + "  "
                                font: picked ? term.bold : term.font
                                color: picked ? Colors.base0E : Colors.base04
                            }
                        }
                    }
                    Row {
                        height: term.line
                        Text { text: "  "; font: term.font }
                        Label { text: "login"; on: lock.field === 1 }
                        Text { text: lock.login; font: term.font; color: Colors.base06 }
                    }
                    Row {
                        height: term.line
                        Text { text: "  "; font: term.font }
                        Label { text: "password"; on: lock.field === 2 }
                        Text { text: "*".repeat(lock.password.length); font: term.font; color: Colors.base06 }
                    }
                    Item { width: 1; height: term.line }
                    Row {
                        height: term.line
                        Text { text: "  "; font: term.font }
                        Text {
                            text: lock.checking ? "…" : lock.message
                            font: term.font
                            color: lock.message === "Login incorrect" ? Colors.base08 : Colors.base04
                        }
                    }
                }
                // the block cursor, where you type (on the desktop line: on the pick)
                Rectangle {
                    width: term.cell
                    height: term.line
                    color: Colors.base06
                    y: term.line * (1 + lock.field - (lock.locking ? 1 : 0))
                    x: term.cell * (2 + 10 + (lock.field === 0
                        ? lock.desktops.slice(0, lock.pick).reduce((n, d) => n + d.length + 4, 0) + 1
                        : lock.field === 1 ? lock.login.length : lock.password.length))
                }
                Text {
                    anchors { bottom: parent.bottom; bottomMargin: 6 }
                    text: lock.locking ? "  ⏎ unlock"
                        : "  ↑↓ line   ←→ desktop   ⏎ " + (lock.field === 2 ? "log in" : "next")
                    font: term.font
                    color: Colors.base04
                }
            }
        }
    }
}

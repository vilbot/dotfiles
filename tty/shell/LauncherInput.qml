// The launcher's text field, the same in the bar (LauncherWindow.qml) and on an empty desktop
// (EmptyDesk.qml): what you type is Launcher.query. Its keys (run, move, complete, favorite, erase,
// Chrome's new window / incognito, close) are the launcher's actions in tty/keys.toml (AppKeys).
// What Tab would add shows dimmed after the text (Launcher.ghost); → at the end takes it too.
import QtQuick

TextInput {
    id: input
    property real cursorWidth: 8
    signal cancelled()
    color: Colors.base07
    selectionColor: Colors.base02
    cursorDelegate: Rectangle { width: input.cursorWidth; color: Colors.base06; visible: input.activeFocus }
    onTextEdited: Launcher.query = text
    Connections {
        target: Launcher
        function onQueryChanged() {
            if (input.text !== Launcher.query) { input.text = Launcher.query; input.cursorPosition = input.text.length }
        }
    }
    Text {   // the ghost: where the text ends, under the cursor's block like a terminal's
        x: input.contentWidth
        anchors.verticalCenter: parent.verticalCenter
        visible: input.cursorPosition === input.text.length
        text: Launcher.ghost
        font: input.font
        color: Colors.base04
    }
    Keys.onPressed: event => {
        const chrome = how => { if (!Launcher.chromePick()) return false; Launcher.run(Launcher.current, how); return true }
        switch (AppKeys.action("launcher", event)) {
        case "launcher.run": Launcher.run(Launcher.current); break
        case "launcher.close": input.cancelled(); break
        case "launcher.next": Launcher.move(1); break
        case "launcher.prev": Launcher.move(-1); break
        case "launcher.complete": Launcher.complete(); break
        case "launcher.take":   // only at the end of the text, with something to take
            if (cursorPosition !== text.length || Launcher.ghost === "") return
            Launcher.complete(); break
        case "launcher.favorite": Launcher.toggleFavorite(Launcher.results[Launcher.current]); break
        case "launcher.clear":   // Cmd+C (Ctrl here) with text selected still copies
            if (input.selectedText !== "" && (event.modifiers & Qt.ControlModifier)) return
            Launcher.query = ""; break
        case "launcher.window": if (!chrome("window")) return; break
        case "launcher.incognito": if (!chrome("incognito")) return; break
        default: return
        }
        event.accepted = true
    }
}

// The launcher's text field, the same in the bar (LauncherWindow.qml) and on an empty desktop
// (EmptyDesk.qml): what you type is Launcher.query; Enter runs, Tab completes, Up/Down (or
// Ctrl+J/K/N/P) move, Ctrl+F adds or removes a favorite, Esc closes (on a desktop: clears).
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
    Keys.onEscapePressed: input.cancelled()
    Keys.onReturnPressed: Launcher.run(Launcher.current)
    Keys.onEnterPressed: Launcher.run(Launcher.current)
    Keys.onUpPressed: Launcher.move(-1)
    Keys.onDownPressed: Launcher.move(1)
    Keys.onTabPressed: Launcher.complete()
    Keys.onBacktabPressed: Launcher.move(-1)
    // physical Ctrl arrives as Super (Meta) through mackeys, as Ctrl without it
    Keys.onPressed: event => {
        if (!(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) return
        const k = event.key
        if (k === Qt.Key_J || k === Qt.Key_N) Launcher.move(1)
        else if (k === Qt.Key_K || k === Qt.Key_P) Launcher.move(-1)
        else if (k === Qt.Key_F) Launcher.toggleFavorite(Launcher.results[Launcher.current])
        else return
        event.accepted = true
    }
}

// The launcher on screen: a see-through strip lying exactly on the middle of the bar, where the
// app's name fades out and the prompt fades in, with the results dropping down below it.
// Its own surface ("tty-launcher") so mackeys knows when it's open (keys/remap.toml).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: launcher
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    readonly property int rows: Launcher.open ? Math.max(1, Math.min(12, Launcher.results.length)) : 0

    // a click anywhere else closes it
    PanelWindow {
        screen: launcher.screen
        visible: Launcher.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "tty-launcher-shade"
        MouseArea { anchors.fill: parent; onClicked: Launcher.close() }
    }

    PanelWindow {
        id: win
        screen: launcher.screen
        visible: Launcher.open || list.height > 0
        anchors.top: true
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Ui.centerWidth
        implicitHeight: Ui.barHeight + Ui.row * 12 + 2
        color: "transparent"
        mask: Region { item: body }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "tty-launcher"
        WlrLayershell.keyboardFocus: Launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: body
            width: parent.width
            height: Ui.barHeight + list.height

            // the prompt, on the bar (the bar shows through)
            Item {
                width: parent.width
                height: Ui.barHeight
                opacity: Launcher.open ? 1 : 0
                y: Launcher.open ? 0 : 6
                Behavior on opacity { NumberAnimation { duration: Ui.quick } }
                Behavior on y { NumberAnimation { duration: Ui.quick; easing.type: Easing.OutCubic } }

                Text {
                    id: caret
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: ">"
                    font: Ui.bold
                    color: Colors.base0E
                }
                TextInput {
                    id: input
                    anchors { left: caret.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
                    font: Ui.font
                    color: Colors.base07
                    selectionColor: Colors.base02
                    cursorDelegate: Rectangle { width: 8; color: Colors.base06; visible: input.activeFocus }
                    onTextEdited: Launcher.query = text
                    Keys.onEscapePressed: Launcher.close()
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
                Connections {
                    target: Launcher
                    function onOpenChanged() { if (Launcher.open) input.forceActiveFocus() }
                    function onQueryChanged() {
                        if (input.text !== Launcher.query) { input.text = Launcher.query; input.cursorPosition = input.text.length }
                    }
                }
            }

            // the results, dropping down from the bar
            Rectangle {
                id: list
                y: Ui.barHeight - 1
                width: parent.width
                height: rows > 0 ? Ui.row * rows + 2 : 0
                clip: true
                color: Colors.base00
                border { color: Colors.base03; width: height > 0 ? 1 : 0 }
                Behavior on height { NumberAnimation { duration: Ui.quick; easing.type: Easing.OutCubic } }

                ListView {   // 12 rows show; a longer list (a folder) scrolls with the pick
                    x: 1; y: 1
                    width: parent.width - 2
                    height: Ui.row * Math.min(12, Math.max(1, count))
                    model: Launcher.results
                    currentIndex: Launcher.current
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool picked: index === Launcher.current
                        width: ListView.view.width
                        height: Ui.row
                        color: picked ? Colors.base02 : "transparent"
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: (row.picked ? "> " : "  ") + (Launcher.favorites.includes(row.modelData.id) ? "* " : "  ") + row.modelData.name
                            font: row.picked ? Ui.bold : Ui.font
                            color: row.modelData.isDir ? Colors.base0D : row.picked ? Colors.base07 : Colors.base06
                        }
                        Text {
                            readonly property bool asking: Launcher.confirming === row.modelData.id
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: asking ? "⏎ again to confirm" : row.modelData.detail
                            font: asking ? Ui.bold : Ui.font
                            color: asking ? Colors.base08 : Colors.base04
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width / 2)
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: Launcher.current = row.index
                            onClicked: Launcher.run(row.index)
                        }
                    }
                }
                Text {  // typed something that matches nothing: Enter runs it
                    visible: Launcher.results.length === 0
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: Launcher.query.trim() === "" ? "no favorites yet: Ctrl+F on an app"
                        : Launcher.pathQuery ? "nothing here" : "⏎ runs it as a command"
                    font: Ui.font
                    color: Colors.base04
                }
            }
        }
    }
}

//@ pragma AppId none-settings
// The None desktop's Settings app: a window of its own (class none-settings), started by
// tty/settings.sh [PAGE] (the launcher's "Settings", Alt+? for Shortcuts), which shows the open
// one instead when there is one. Pages: Shortcuts (tty/keys.json), Appearance (the colour theme),
// Keyboard & mouse (Hyprland's input options, tty/settings.json).
// Its keys are the settings.* actions in tty/keys.json (AppKeys); the mouse picks what it's over.
// Run by hand to see errors:  qs -p ~/dotfiles/tty/settings
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: app
    readonly property var pages: [
        { id: "shortcuts", name: "Shortcuts", file: "ShortcutsPage.qml", note: "tty/keys.json" },
        { id: "appearance", name: "Appearance", file: "AppearancePage.qml", note: "tty/theme.py" },
        { id: "input", name: "Keyboard & mouse", file: "InputPage.qml", note: "tty/settings.json" },
    ]
    property int pageIndex: Math.max(0, pages.findIndex(p => p.id === Quickshell.env("NONE_SETTINGS_PAGE")))
    function open(id) { const i = pages.findIndex(p => p.id === id); if (i >= 0) pageIndex = i }

    IpcHandler {
        target: "settings"
        function open(page: string): void { app.open(page) }   // tty/settings.sh focuses the window
        function search(text: string): void { app.query = text }
    }
    property string query: ""

    FloatingWindow {
        id: win
        title: "Settings"
        visible: true
        implicitWidth: 1040
        implicitHeight: 720
        color: Style.bg
        onVisibleChanged: if (!visible) { Keymap.cancel(); Qt.quit() }   // closed (Super+Q): the app is done

        readonly property var page: loader.item
        property alias query: app.query

        // ---- keys ----------------------------------------------------------------------------
        // in the search box only these act (and none of them when they'd type a character)
        readonly property var whileTyping: ["settings.back", "settings.next", "settings.prev", "settings.activate",
            "settings.page.next", "settings.page.prev", "settings.undo", "settings.redo", "settings.close", "settings.search"]
        function handle(event, typing) {
            if (Keymap.recording) { Keymap.keyEvent(event); return true }   // the Shortcuts page records them
            const a = AppKeys.action("settings", event)
            if (typing && (AppKeys.plain(event) || !whileTyping.includes(a))) return false
            const p = page
            if (p) p.mouseLive = false
            switch (a) {
            case "settings.next": p.next(); break
            case "settings.prev": p.prev(); break
            case "settings.activate": if (typing) leaveSearch(); else p.activate(); break
            case "settings.add": p.addKey(); break
            case "settings.unbind": p.unbind(); break
            case "settings.lower": p.lower(); break
            case "settings.higher": p.higher(); break
            case "settings.undo": p.undo(); break
            case "settings.redo": p.redo(); break
            case "settings.search": search.forceActiveFocus(); search.selectAll(); break
            case "settings.back":
                if (typing) leaveSearch()
                else if (!p.back() && query) query = ""
                break
            case "settings.page.next": pageIndex = (pageIndex + 1) % pages.length; break
            case "settings.page.prev": pageIndex = (pageIndex + pages.length - 1) % pages.length; break
            case "settings.close": win.visible = false; break
            default:
                // typing a letter that isn't a key here starts a search with it
                if (!typing && AppKeys.plain(event)) {
                    win.query = event.text; search.forceActiveFocus(); search.cursorPosition = search.text.length; return true
                }
                return false
            }
            return true
        }
        function leaveSearch() { keys.forceActiveFocus() }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => { event.accepted = win.handle(event, false) }
        }
        // the mouse picks what it's over, but only once it moves (not when the list scrolls under it)
        HoverHandler {
            property point last
            onPointChanged: {
                const p = point.position
                if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 1 && win.page) win.page.mouseLive = true
                last = p
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---- the pages -----------------------------------------------------------------------
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 230
                color: Style.bg
                ColumnLayout {
                    anchors { fill: parent; topMargin: 22; bottomMargin: 18 }
                    spacing: 2
                    Text {
                        Layout.leftMargin: 22
                        Layout.bottomMargin: 22
                        textFormat: Text.StyledText
                        text: "<font color='" + Style.accent + "'>&gt;</font> settings"
                        font: Style.title
                        color: Style.strong
                    }
                    Repeater {
                        model: app.pages
                        delegate: Rectangle {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool current: app.pageIndex === index
                            Layout.fillWidth: true
                            implicitHeight: Style.row
                            color: area.containsMouse ? Style.raised : "transparent"
                            Behavior on color { ColorAnimation { duration: Style.quick } }
                            Rectangle { width: 3; height: parent.height; color: Style.accent; visible: entry.current }
                            Text {
                                anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                                text: entry.modelData.name
                                font: entry.current ? Style.bold : Style.font
                                color: entry.current ? Style.strong : area.containsMouse ? Style.text : Style.dim
                            }
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: app.pageIndex = entry.index
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.leftMargin: 22
                        text: app.pages[app.pageIndex].note
                        font: Style.small
                        color: Style.faint
                    }
                }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Style.line }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ---- title and search ---------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 22
                    Layout.leftMargin: Style.pad
                    Layout.rightMargin: Style.pad
                    Layout.bottomMargin: 6
                    spacing: 16
                    Text {
                        Layout.fillWidth: true
                        text: app.pages[app.pageIndex].name
                        font: Style.title
                        color: Style.strong
                    }
                    Rectangle {
                        Layout.preferredWidth: 320
                        implicitHeight: 30
                        color: search.activeFocus ? Style.raised : "transparent"
                        border.width: 1
                        border.color: search.activeFocus ? Style.accent : searchArea.containsMouse ? Style.dim : Style.line
                        Behavior on border.color { ColorAnimation { duration: Style.quick } }
                        MouseArea {
                            id: searchArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            onClicked: search.forceActiveFocus()
                        }
                        Text {
                            id: slash
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "/"
                            font: Style.bold
                            color: search.activeFocus ? Style.accent : Style.dim
                        }
                        TextInput {
                            id: search
                            anchors { left: slash.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            font: Style.font
                            color: Style.strong
                            selectionColor: Style.line
                            clip: true
                            text: win.query
                            onTextEdited: win.query = text
                            cursorDelegate: Rectangle { width: 8; color: Style.text; visible: search.activeFocus }
                            Keys.onPressed: event => { event.accepted = win.handle(event, true) }
                            Text {
                                visible: !search.text
                                text: app.pageIndex === 0 ? "search actions or keys" : "search"
                                font: Style.font
                                color: Style.faint
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; implicitHeight: 1; color: Style.line }

                Loader {
                    id: loader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    source: app.pages[app.pageIndex].file
                    onLoaded: item.query = Qt.binding(() => win.query)
                }

                // ---- what the keys do here, and what happened ---------------------------------------
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Style.line }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    Layout.leftMargin: Style.pad
                    Layout.rightMargin: Style.pad
                    spacing: 16
                    Text {
                        text: win.page ? win.page.hints : ""
                        font: Style.small
                        color: Style.dim
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: win.page ? (win.page.ask ? win.page.ask.text : win.page.message) : ""
                        font: Style.small
                        color: win.page && (win.page.ask || win.page.messageBad) ? (win.page.ask ? Style.accent : Style.bad) : Style.good
                    }
                }
            }
        }
    }
}

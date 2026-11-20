// Appearance: None's colour theme (tty/theme.py). Every theme/*.yaml with its colours; a click
// (or Enter) switches to it everywhere at once: the shell, open terminals, nvim, Hyprland.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: page
    property string query: ""
    property bool mouseLive: true
    property int current: 0
    readonly property string hints: "⏎ use   / search"
    property string message: ""
    property bool messageBad: false

    readonly property string themePy: Quickshell.shellDir + "/../theme.py"
    property var themes: []
    readonly property string now: Colors.theme.name ?? "gruver16"
    readonly property var shown: themes.filter(t => !query.trim() || query.trim().toLowerCase().split(/\s+/)
                                                .every(w => (t.name + " " + t.variant + " theme colours colors").includes(w)))
    readonly property var row: shown[current] ?? null
    onQueryChanged: current = 0
    onThemesChanged: { const i = (shown ?? []).findIndex(t => t.name === now); if (i >= 0) current = i }

    Process {
        running: true
        command: ["python3", page.themePy, "themes"]
        stdout: StdioCollector { onStreamFinished: { try { page.themes = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: setter
        stderr: StdioCollector { onStreamFinished: if (text.trim()) { page.message = text.trim().split("\n").pop(); page.messageBad = true } }
    }
    function use(t) {
        if (!t || setter.running) return
        message = ""; messageBad = false
        setter.command = ["python3", themePy, "set", t.name]
        setter.running = true
    }

    function next() { if (current < shown.length - 1) current++ }
    function prev() { if (current > 0) current-- }
    function activate() { use(row) }
    function lower() { prev() }
    function higher() { next() }
    function addKey() {}
    function unbind() {}
    function back() { return false }
    function undo() {}
    function redo() {}

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: parent.width
            Item {
                width: parent.width; height: 48
                Text {
                    anchors { left: parent.left; leftMargin: Style.pad; bottom: parent.bottom; bottomMargin: 8 }
                    text: "COLOUR THEME"
                    font: Style.heading
                    color: Style.accent
                }
            }
            Repeater {
                model: page.shown
                delegate: Rectangle {
                    id: r
                    required property var modelData
                    required property int index
                    readonly property bool picked: index === page.current
                    readonly property bool inUse: modelData.name === page.now
                    width: col.width
                    height: 64
                    color: picked ? Style.raised : "transparent"
                    Behavior on color { ColorAnimation { duration: Style.quick } }
                    Rectangle {
                        width: 3; height: parent.height
                        color: Style.accent
                        opacity: r.picked ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Style.quick } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (page.mouseLive) page.current = r.index
                        onPositionChanged: page.current = r.index
                        onClicked: { page.current = r.index; page.use(r.modelData) }
                    }
                    RowLayout {
                        anchors { fill: parent; leftMargin: Style.pad; rightMargin: Style.pad }
                        spacing: 20
                        // a little terminal in the theme's colours
                        Rectangle {
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 44
                            color: r.modelData.base00
                            border.width: 1
                            border.color: r.inUse ? Style.accent : Style.line
                            Column {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 1
                                Text {
                                    textFormat: Text.RichText
                                    font: Style.small
                                    text: "<span style='color:" + r.modelData.base0E + "'>&gt;</span> "
                                        + "<span style='color:" + r.modelData.base06 + "'>ls </span>"
                                        + "<span style='color:" + r.modelData.base0D + "'>~/dotfiles</span>"
                                }
                                Text {
                                    textFormat: Text.RichText
                                    font: Style.small
                                    text: "<span style='color:" + r.modelData.base0B + "'>ok</span> "
                                        + "<span style='color:" + r.modelData.base08 + "'>err</span> "
                                        + "<span style='color:" + r.modelData.base04 + "'># note</span>"
                                }
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: r.modelData.name + (r.inUse ? "   in use" : "")
                                font: r.inUse ? Style.bold : Style.font
                                color: r.picked || r.inUse ? Style.strong : Style.text
                            }
                            Text { text: r.modelData.variant; font: Style.small; color: Style.dim }
                        }
                        Rectangle {   // its 16 colours
                            implicitWidth: swatches.width + 2
                            implicitHeight: swatches.height + 2
                            color: "transparent"
                            border.width: 1
                            border.color: Style.line
                        Row {
                            id: swatches
                            x: 1; y: 1
                            spacing: 0
                            Repeater {
                                model: ["00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "0A", "0B", "0C", "0D", "0E", "0F"]
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 14; height: 22
                                    color: r.modelData["base" + modelData]
                                }
                            }
                        }
                        }
                    }
                }
            }
        }
    }
}

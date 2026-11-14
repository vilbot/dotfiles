// Opt+? cheat sheet: every keymap bind on a gallery-style card over the dimmed desktop.
// Rows come from Keymap.qml (keys/keymap.toml through keys/build.py): only actions with a key.
// "edit" opens the settings window's Shortcuts page.
// Toggle: `qs ipc call keybinds toggle` (bound to Opt+? in hypr/binds.lua). Esc or a click closes.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    property bool shown: false

    // open on the monitor that has focus
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: shown

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-keybinds"   // hypr/hyprland.lua blurs this layer
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Qt.rgba(0.10, 0.09, 0.08, 0.35)   // dim the desktop behind the card

    IpcHandler {
        target: "keybinds"
        function toggle(): void { root.shown = !root.shown }
        function open(): void { root.shown = true }   // (not "show": clashes with `qs ipc show`)
        function close(): void { root.shown = false }
    }

    // click anywhere (outside or on the card) to close
    MouseArea { anchors.fill: parent; onClicked: root.shown = false }

    Item {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: root.shown = false
        Keys.onPressed: event => {
            // Opt+? again (Alt+Shift+/) also closes, in case the overlay holds keyboard focus
            if (event.key === Qt.Key_Question || event.key === Qt.Key_Slash) root.shown = false
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: content.implicitWidth + 2 * 48
            height: content.implicitHeight + 2 * 40
            color: Qt.rgba(0.953, 0.937, 0.902, 0.97)   // Theme.wall, nearly opaque
            border { color: Theme.hairline; width: 1 }
            radius: 2

            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.98
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 26

                // title, like an exhibition label
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Keyboard"
                        color: Theme.ink
                        font: Qt.font({ family: Theme.fontFamily, pixelSize: 30, italic: true })
                    }
                    RowLayout {
                        spacing: 18
                        Text {
                            text: "HYPRLAND  ·  ⌥ IS THE WINDOW KEY"
                            color: Theme.inkFaint
                            font: Theme.textCaps
                        }
                        LinkText {
                            text: "edit"
                            onClicked: { root.shown = false; Panels.openSettings("Shortcuts") }
                        }
                    }
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 56
                    rowSpacing: 26

                    Repeater {
                        model: Keymap.boundGroups

                        ColumnLayout {
                            id: group
                            required property var modelData
                            Layout.alignment: Qt.AlignTop
                            Layout.minimumWidth: 340
                            spacing: 7

                            Text {
                                text: group.modelData.title.toUpperCase()
                                color: Theme.inkDim
                                font: Theme.textCaps
                            }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline }

                            Repeater {
                                model: group.modelData.rows

                                RowLayout {
                                    id: row
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 24

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.label
                                        color: Theme.ink
                                        font: Theme.text
                                    }
                                    Text {
                                        text: row.modelData.hyprLabel.join("   or   ")
                                        color: Theme.inkDim
                                        font: Theme.text
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

// The settings window: pages listed on the left (schema.js). Opens from the control center, the
// palette, or `qs ipc call settings toggle` (`page <name>` opens at a page).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import "schema.js" as Schema

Scope {
    id: root
    property int page: 0

    function openPage(name) {
        const i = Schema.pages.findIndex(p => p.name.toLowerCase() === name.toLowerCase())
        if (i >= 0) page = i
        Panels.settingsOpen = true
    }
    IpcHandler {
        target: "settings"
        function toggle(): void { Panels.settingsOpen = !Panels.settingsOpen }
        function open(): void { Panels.settingsOpen = true }
        function close(): void { Panels.settingsOpen = false }
        function page(name: string): void { root.openPage(name) }
    }
    Connections {
        target: Panels
        function onSettingsPageChanged() {
            if (Panels.settingsPage) { root.openPage(Panels.settingsPage); Panels.settingsPage = "" }
        }
    }

    // A new window each time: once closed from outside (Cmd+Q), Quickshell can't show the same one again.
    LazyLoader {
        active: Panels.settingsOpen
        FloatingWindow {
            title: "Settings"      // hypr/hyprland.lua floats it by this title
            visible: true
            implicitWidth: 900
            implicitHeight: 620
            color: Theme.paper
            Component.onCompleted: HyprSettings.reload()
            onVisibleChanged: if (!visible) Panels.settingsOpen = false

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Panels.settingsOpen = false
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                ColumnLayout {
                    Layout.preferredWidth: 220
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    Layout.margins: 28
                    spacing: 10
                    Text { text: "Settings"; color: Theme.ink; font: Theme.heading; Layout.bottomMargin: 14 }
                    Repeater {
                        model: Schema.pages
                        delegate: Text {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool current: root.page === index
                            text: modelData.name
                            color: current || area.containsMouse ? Theme.ink : Theme.inkDim
                            font: current ? Theme.text : Theme.textItalic
                            Rectangle {    // marker for the current page
                                visible: entry.current
                                anchors { right: parent.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                width: 12; height: 1; color: Theme.ink
                            }
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.page = entry.index; flick.contentY = 0 }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "Saved to hypr/settings.json.\nKeys: keys/remap.toml."
                        wrapMode: Text.Wrap
                        color: Theme.inkFaint
                        font: Theme.textSmall
                    }
                }
                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.hairline }

                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.preferredWidth: 600
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: pageCol.implicitHeight + 56
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: pageCol
                        x: 36; y: 28
                        width: flick.width - 72
                        spacing: 0

                        Text {
                            text: Schema.pages[root.page].name
                            color: Theme.ink
                            font: Theme.heading
                            Layout.bottomMargin: 18
                        }
                        Loader {
                            Layout.fillWidth: true
                            readonly property var p: Schema.pages[root.page]
                            source: p.page ?? "OptionsPage.qml"
                            onLoaded: if (!p.page) item.options = Qt.binding(() => Schema.pages[root.page].options ?? [])
                        }
                    }
                }
            }
        }
    }
}

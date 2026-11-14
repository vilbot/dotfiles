// Settings window page: the wallpaper (WallpaperState.qml). One path: a picture, or a folder for
// a slideshow of the pictures in it, with how often it changes and how a new picture comes in.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page
    spacing: 0

    readonly property var intervals: [[60, "1 minute"], [300, "5 minutes"], [900, "15 minutes"], [1800, "30 minutes"],
                                      [3600, "1 hour"], [10800, "3 hours"], [86400, "1 day"]]
    readonly property var transitions: [["fade", "Fade"], ["slide", "Slide"], ["zoom", "Zoom"], ["none", "None"]]

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 16
        text: "A picture, or a folder for a slideshow of the pictures in it (jpg, png, webp, avif). "
            + "Enter to use it; ~ is your home folder."
        wrapMode: Text.Wrap
        color: Theme.inkDim
        font: Theme.textSmall
    }

    // ---- path ----
    Row {
        Layout.fillWidth: true
        spacing: 16
        Text { width: 140; text: "Picture or folder"; color: Theme.ink; font: Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            width: parent.width - 156
            height: 26
            color: "transparent"
            radius: 2
            border { width: 1; color: field.activeFocus ? Theme.inkDim : Theme.hairline }
            TextInput {
                id: field
                anchors { fill: parent; leftMargin: 7; rightMargin: 7 }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Theme.ink
                selectByMouse: true
                font: Qt.font({ family: Theme.fontFamily, pixelSize: Theme.fontSize - 1 })
                text: WallpaperState.path
                onAccepted: WallpaperState.setPath(text)
            }
        }
    }
    Text {
        Layout.leftMargin: 156
        Layout.topMargin: 6
        Layout.bottomMargin: 18
        text: !WallpaperState.found ? "Nothing there."
            : WallpaperState.isFolder ? (WallpaperState.images.length === 1 ? "1 picture." : WallpaperState.images.length === 0
                                         ? "No pictures in this folder." : WallpaperState.images.length + " pictures, a slideshow.")
            : "One picture."
        color: !WallpaperState.found || (WallpaperState.isFolder && !WallpaperState.images.length) ? Theme.urgent : Theme.inkFaint
        font: Theme.textSmall
    }

    // ---- slideshow ----
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.hairline; visible: slideshow.visible }
    ColumnLayout {
        id: slideshow
        Layout.fillWidth: true
        Layout.topMargin: 14
        visible: WallpaperState.isFolder && WallpaperState.images.length > 1
        spacing: 16
        RowLayout {
            spacing: 16
            Text { Layout.preferredWidth: 140; Layout.alignment: Qt.AlignTop; text: "Change every"; color: Theme.ink; font: Theme.text }
            Flow {
                Layout.fillWidth: true
                spacing: 14
                Repeater {
                    model: page.intervals
                    delegate: Pick {
                        required property var modelData
                        text: modelData[1]
                        selected: WallpaperState.interval === modelData[0]
                        onClicked: WallpaperState.setInterval(modelData[0])
                    }
                }
            }
        }
        RowLayout {
            spacing: 16
            Text { Layout.preferredWidth: 140; text: "Transition"; color: Theme.ink; font: Theme.text }
            Row {
                spacing: 14
                Repeater {
                    model: page.transitions
                    delegate: Pick {
                        required property var modelData
                        text: modelData[1]
                        selected: WallpaperState.transition === modelData[0]
                        onClicked: WallpaperState.setTransition(modelData[0])
                    }
                }
            }
        }
    }

    // a choice, like the settings window's own: italic, underlined when chosen
    component Pick: Text {
        id: pk
        property bool selected
        signal clicked()
        color: selected || pa.containsMouse ? Theme.ink : Theme.inkDim
        font: selected ? Theme.text : Theme.textItalic
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 1 }
            height: 1; color: Theme.ink; visible: pk.selected
        }
        MouseArea {
            id: pa
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pk.clicked()
        }
    }
}

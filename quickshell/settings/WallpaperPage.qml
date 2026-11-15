// The wallpaper (services/Wallpaper.qml): a picture, or a folder for a slideshow, with how often
// it changes and how a new picture comes in.
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

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
        TextBox {
            width: parent.width - 156
            text: Wallpaper.path
            onAccepted: t => Wallpaper.setPath(t)
        }
    }
    Text {
        Layout.leftMargin: 156
        Layout.topMargin: 6
        Layout.bottomMargin: 18
        text: !Wallpaper.found ? "Nothing there."
            : Wallpaper.isFolder ? (Wallpaper.images.length === 1 ? "1 picture." : Wallpaper.images.length === 0
                                         ? "No pictures in this folder." : Wallpaper.images.length + " pictures, a slideshow.")
            : "One picture."
        color: !Wallpaper.found || (Wallpaper.isFolder && !Wallpaper.images.length) ? Theme.urgent : Theme.inkFaint
        font: Theme.textSmall
    }

    // ---- slideshow ----
    Divider { visible: slideshow.visible }
    ColumnLayout {
        id: slideshow
        Layout.fillWidth: true
        Layout.topMargin: 14
        visible: Wallpaper.isFolder && Wallpaper.images.length > 1
        spacing: 16
        RowLayout {
            spacing: 16
            Text { Layout.preferredWidth: 140; Layout.alignment: Qt.AlignTop; text: "Change every"; color: Theme.ink; font: Theme.text }
            Choices {
                choices: page.intervals
                isSelected: v => Wallpaper.interval === v
                onPicked: v => Wallpaper.setInterval(v)
            }
        }
        RowLayout {
            spacing: 16
            Text { Layout.preferredWidth: 140; text: "Transition"; color: Theme.ink; font: Theme.text }
            Choices {
                choices: page.transitions
                isSelected: v => Wallpaper.transition === v
                onPicked: v => Wallpaper.setTransition(v)
            }
        }
    }

}

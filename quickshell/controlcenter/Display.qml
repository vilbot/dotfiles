// Brightness and night light (services/Brightness.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

ColumnLayout {
    spacing: 8
    visible: Brightness.available

    Text { text: "DISPLAY"; color: Theme.inkFaint; font: Theme.textCaps }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        SymbolIcon { implicitSize: 16; source: Quickshell.iconPath("brightness-high-symbolic", "display-brightness-symbolic") }
        Slider {
            Layout.fillWidth: true
            value: Brightness.value / 100
            onMoved: v => Brightness.set(v * 100)
        }
        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: Brightness.value + "%"
            color: Theme.inkDim
            font: Theme.text
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Brightness.hasSunset
        spacing: 10
        SymbolIcon { implicitSize: 16; source: Quickshell.iconPath("redshift-status-on", "weather-clear-night-symbolic") }
        Text { Layout.fillWidth: true; text: "Night light"; color: Theme.ink; font: Theme.text }
        Toggle { checked: Brightness.nightLight; onToggled: v => Brightness.nightLight = v }
    }
}

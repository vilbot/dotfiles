// Control center: Bluetooth on/off and paired devices. Click a device to connect or disconnect.
// Pairing new devices: "Pair a new device…" opens KDE's Bluetooth settings.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth

ColumnLayout {
    id: root
    spacing: 8
    visible: adapter !== null

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: !on ? []
        : adapter.devices.values.filter(d => d.paired || d.bonded)
              .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))

    Text { text: "BLUETOOTH"; color: Theme.inkFaint; font: Theme.textCaps }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        IconImage { implicitSize: 16; source: Quickshell.iconPath(root.on ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic", "bluetooth-symbolic") }
        Text { Layout.fillWidth: true; text: "Bluetooth"; color: Theme.ink; font: Theme.text }
        Toggle {
            checked: root.on
            onToggled: v => { if (root.adapter) root.adapter.enabled = v }
        }
    }

    Repeater {
        model: root.devices
        delegate: Item {
            id: dev
            required property var modelData
            readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                                      || modelData.state === BluetoothDeviceState.Disconnecting
            Layout.fillWidth: true
            Layout.leftMargin: 26
            implicitHeight: row.implicitHeight + 2

            RowLayout {
                id: row
                anchors.fill: parent
                spacing: 6
                IconImage {
                    implicitSize: 14
                    source: Quickshell.iconPath(dev.modelData.icon || "bluetooth", "bluetooth")
                }
                Text {
                    Layout.fillWidth: true
                    text: dev.modelData.name || dev.modelData.deviceName
                    elide: Text.ElideRight
                    color: dev.modelData.connected || area.containsMouse ? Theme.ink : Theme.inkDim
                    font: dev.modelData.connected ? Theme.text : Theme.textItalic
                }
                Text {
                    text: dev.modelData.state === BluetoothDeviceState.Connecting ? "connecting…"
                        : dev.modelData.state === BluetoothDeviceState.Disconnecting ? "disconnecting…"
                        : dev.modelData.connected && dev.modelData.batteryAvailable ? Math.round(dev.modelData.battery * 100) + "%"
                        : ""
                    visible: text !== ""
                    color: Theme.inkFaint
                    font: Theme.textSmall
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!dev.busy) dev.modelData.connected = !dev.modelData.connected
            }
        }
    }

    LinkText {
        Layout.leftMargin: 26
        visible: root.on
        text: "Pair a new device…"
        onClicked: {
            Panels.controlOpen = false
            Quickshell.execDetached(["systemsettings", "kcm_bluetooth"])
        }
    }
}

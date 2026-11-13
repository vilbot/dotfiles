// Control center: wired status, Wi-Fi on/off and networks (NetworkManager).
// Click a network to join it; secured networks you haven't joined before ask for the password.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking

ColumnLayout {
    id: root
    spacing: 8
    property bool open: false                      // panel visible: scan for networks only then

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var networks: !wifi || !Networking.wifiEnabled ? []
        : wifi.networks.values.filter(n => n.name !== "")
              .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
              .slice(0, 8)
    property string asking: ""                     // network name waiting for a password
    property string failed: ""                     // network name that just failed to join

    Binding { target: root.wifi; property: "scannerEnabled"; value: root.open; when: root.wifi !== null }
    onOpenChanged: if (!open) { asking = ""; failed = "" }

    Text { text: "NETWORK"; color: Theme.inkFaint; font: Theme.textCaps }

    // wired
    RowLayout {
        Layout.fillWidth: true
        visible: root.wired !== null
        spacing: 10
        IconImage { implicitSize: 16; source: Quickshell.iconPath("network-wired-symbolic") }
        Text { text: "Ethernet"; color: Theme.ink; font: Theme.text }
        Item { Layout.fillWidth: true }
        Text {
            text: !root.wired ? "" : root.wired.connected
                ? (root.wired.linkSpeed > 0 ? root.wired.linkSpeed + " Mb/s" : "connected")
                : root.wired.hasLink ? "not connected" : "unplugged"
            color: Theme.inkDim
            font: Theme.textItalic
        }
    }

    // wifi switch
    RowLayout {
        Layout.fillWidth: true
        visible: root.wifi !== null
        spacing: 10
        IconImage { implicitSize: 16; source: Quickshell.iconPath(Networking.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic") }
        Text { Layout.fillWidth: true; text: "Wi-Fi"; color: Theme.ink; font: Theme.text }
        Toggle {
            enabled: Networking.wifiHardwareEnabled
            checked: Networking.wifiEnabled
            onToggled: v => Networking.wifiEnabled = v
        }
    }

    Text {
        visible: root.wifi !== null && Networking.wifiEnabled && root.networks.length === 0
        Layout.leftMargin: 26
        text: "Looking for networks…"
        color: Theme.inkFaint
        font: Theme.textItalic
    }

    Repeater {
        model: root.networks
        delegate: ColumnLayout {
            id: net
            required property var modelData
            readonly property bool secured: modelData.security !== WifiSecurityType.Open
            Layout.fillWidth: true
            Layout.leftMargin: 26
            spacing: 4

            Connections {
                target: net.modelData
                function onConnectionFailed(reason) {
                    root.failed = net.modelData.name
                    if (reason === ConnectionFailReason.NoSecrets) root.asking = net.modelData.name
                }
                function onConnectedChanged() {
                    if (net.modelData.connected && root.asking === net.modelData.name) root.asking = ""
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: name.implicitHeight + 2
                RowLayout {
                    anchors.fill: parent
                    spacing: 6
                    Text {
                        id: name
                        Layout.fillWidth: true
                        text: (net.modelData.connected ? "• " : "") + net.modelData.name
                        elide: Text.ElideRight
                        color: net.modelData.connected || area.containsMouse ? Theme.ink : Theme.inkDim
                        font: net.modelData.connected ? Theme.text : Theme.textItalic
                    }
                    Text {
                        text: net.modelData.stateChanging ? "joining…"
                            : root.failed === net.modelData.name && !net.modelData.connected ? "failed"
                            : net.secured && !net.modelData.known ? "locked" : ""
                        visible: text !== ""
                        color: text === "failed" ? Theme.urgent : Theme.inkFaint
                        font: Theme.textSmall
                    }
                    // signal: ▂▄▆█, faint beyond the strength
                    Row {
                        spacing: 1
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 3
                                height: 4 + index * 3
                                color: net.modelData.signalStrength > index * 0.25 ? Theme.inkDim : Theme.hairline
                            }
                        }
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const n = net.modelData
                        root.failed = ""
                        if (n.connected) n.disconnect()
                        else if (n.known || !net.secured) n.connect()
                        else root.asking = root.asking === n.name ? "" : n.name
                    }
                }
            }

            // password field
            Rectangle {
                visible: root.asking === net.modelData.name
                Layout.fillWidth: true
                implicitHeight: 28
                color: "transparent"
                border { color: Theme.hairline; width: 1 }
                radius: 2
                TextInput {
                    id: psk
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.ink
                    font: Theme.text
                    focus: parent.visible
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                    onAccepted: if (text.length > 0) { root.failed = ""; net.modelData.connectWithPsk(text) }
                    Text {
                        visible: psk.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password, then Enter"
                        color: Theme.inkFaint
                        font: Theme.textItalic
                    }
                }
            }
        }
    }
}

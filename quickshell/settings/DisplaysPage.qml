// Each monitor: resolution, refresh rate, scale. A change has to be kept within 15 s.
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

ColumnLayout {
    spacing: 0
    Repeater {
        model: HyprSettings.monitors
        delegate: Monitor { required property var modelData; monitor: modelData }
    }

    component Monitor: ColumnLayout {
        id: mb
        property var monitor
        Layout.fillWidth: true
        spacing: 0

        // "2560x1440@200.00Hz" -> { w, h, r }
        readonly property var modes: monitor.availableModes.map(s => {
            const m = s.match(/(\d+)x(\d+)@([\d.]+)/)
            return { w: Number(m[1]), h: Number(m[2]), r: Number(m[3]) }
        })
        readonly property var sizes: modes.map(m => m.w + "x" + m.h).filter((s, i, a) => a.indexOf(s) === i).slice(0, 8)
        readonly property string size: monitor.width + "x" + monitor.height
        readonly property var rates: modes.filter(m => m.w + "x" + m.h === size).map(m => m.r).sort((a, b) => b - a)
        function tryMode(w, h, r, scale) { HyprSettings.tryMonitor(monitor, HyprSettings.modeString(w, h, r), scale) }

        Text { text: mb.monitor.make + " " + mb.monitor.model; color: Theme.ink; font: Theme.strong }
        Text {
            text: mb.monitor.name + " · " + mb.size + " at " + Math.round(mb.monitor.refreshRate) + " Hz · scale " + mb.monitor.scale
            color: Theme.inkDim
            font: Theme.textItalic
            Layout.bottomMargin: 6
        }
        Divider {}

        Setting {
            label: "Resolution"
            choices: mb.sizes.map(s => [s, s.replace("x", " × ")])
            isSelected: c => c === mb.size
            onPicked: c => {
                const [w, h] = c.split("x").map(Number)
                const best = mb.modes.filter(m => m.w === w && m.h === h).sort((a, b) => b.r - a.r)[0]
                mb.tryMode(w, h, best.r, mb.monitor.scale)
            }
        }
        Setting {
            label: "Refresh rate"
            choices: mb.rates.map(r => [r, Math.round(r) + " Hz"])
            isSelected: c => Math.abs(c - mb.monitor.refreshRate) < 0.05
            onPicked: c => mb.tryMode(mb.monitor.width, mb.monitor.height, c, mb.monitor.scale)
        }
        Setting {
            label: "Scale"
            choices: [[1, "100%"], [1.25, "125%"], [1.5, "150%"], [1.6, "160%"], [2, "200%"]]
            isSelected: c => Math.abs(c - mb.monitor.scale) < 0.01
            onPicked: c => mb.tryMode(mb.monitor.width, mb.monitor.height, mb.monitor.refreshRate, c)
        }

        RowLayout {
            visible: HyprSettings.trial !== null && HyprSettings.trial.monitor.name === mb.monitor.name
            Layout.fillWidth: true
            Layout.topMargin: 14
            spacing: 18
            Text {
                Layout.fillWidth: true
                text: "Keep this display setting? Reverting in " + HyprSettings.trialLeft + " s."
                color: Theme.urgent
                font: Theme.textItalic
            }
            LinkText { text: "Keep"; onClicked: HyprSettings.keepTrial() }
            LinkText { text: "Revert"; onClicked: HyprSettings.revertTrial() }
        }
        Item { implicitHeight: 28 }
    }

    component Setting: ColumnLayout {
        id: st
        property string label
        property alias choices: picks.choices
        property alias isSelected: picks.isSelected
        signal picked(var value)
        Layout.fillWidth: true
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            spacing: 16
            Text { text: st.label; color: Theme.ink; font: Theme.text; Layout.preferredWidth: 250; Layout.alignment: Qt.AlignTop }
            Choices {
                id: picks
                spacing: 18
                onPicked: v => { if (!isSelected(v)) st.picked(v) }
            }
        }
        Divider {}
    }
}

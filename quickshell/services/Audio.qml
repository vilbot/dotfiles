// Sound devices (Pipewire): the default output and input, and the other ones to switch to.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)

    // Pipewire objects only report live values while tracked
    PwObjectTracker { objects: [root.sink, root.source] }

    function volume(node) { return node?.audio?.volume ?? 0 }
    function muted(node) { return node?.audio?.muted ?? false }
    function setVolume(node, v) { if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, v)) }
    function toggleMute(node) { if (node?.audio) node.audio.muted = !node.audio.muted }
    function makeDefault(node) {
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }
    function label(node) { return node.description || node.nickname || node.name }
    function icon(node) {
        const v = volume(node)
        if (!node?.isSink) return muted(node) ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
        return muted(node) || v === 0 ? "audio-volume-muted-symbolic"
             : v < 0.34 ? "audio-volume-low-symbolic"
             : v < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"
    }
}

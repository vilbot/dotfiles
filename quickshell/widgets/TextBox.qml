// A text field: thin frame, darker while typing. `placeholder` shows while it's empty;
// `invalid` draws the frame red, `changed` tints it (an unsaved edit).
import QtQuick
import qs.services

Rectangle {
    id: box
    property alias text: input.text
    property alias font: input.font
    property alias echoMode: input.echoMode
    property alias validator: input.validator
    property alias maximumLength: input.maximumLength
    property string placeholder: ""
    property bool invalid: false
    property bool changed: false
    signal edited(string text)
    signal accepted(string text)

    function focusInput() { input.forceActiveFocus() }

    implicitWidth: 160
    implicitHeight: 26
    radius: 2
    color: changed ? Theme.hover : "transparent"
    border { width: 1; color: invalid ? Theme.urgent : input.activeFocus ? Theme.inkDim : Theme.hairline }

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 7; rightMargin: 7 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.ink
        selectByMouse: true
        font: Theme.input
        onTextEdited: box.edited(text)
        onAccepted: box.accepted(text)
    }
    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: !input.text
        text: box.placeholder
        color: Theme.inkFaint
        font: Theme.textItalic
    }
}

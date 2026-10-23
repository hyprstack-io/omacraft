import QtQuick
import QtQuick.Controls

// A slim search box: a magnifier, the text, and a clear button once there
// is something to clear. Sits in a row of chips without towering over them.
Rectangle {
    id: box
    property alias text: field.text
    property alias placeholderText: field.placeholderText

    implicitWidth: 220
    implicitHeight: 34
    radius: 9
    color: theme.sunken
    border.color: field.activeFocus ? theme.accent : theme.border

    Label {
        id: glass
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f0349}"
        color: theme.textFaint
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }
    TextField {
        id: field
        anchors.left: glass.right
        anchors.right: clear.left
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 6
        rightPadding: 4
        topPadding: 0
        bottomPadding: 0
        font.pixelSize: 12
        background: null
        Keys.onEscapePressed: event => {
            if (text === "") { event.accepted = false; return; }
            text = "";
        }
    }
    ToolButton {
        id: clear
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: field.text !== ""
        width: visible ? 28 : 6
        height: 28
        text: "\u{f0156}"
        font.pixelSize: 12
        focusPolicy: Qt.NoFocus
        onClicked: field.text = ""
    }
}

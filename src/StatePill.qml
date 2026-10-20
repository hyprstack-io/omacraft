import QtQuick
import QtQuick.Controls

// A plugin's state, coloured by whether it's doing its job.
Rectangle {
    property string text
    property bool on: false
    property bool warn: false
    readonly property color tone: Qt.color(theme.accent)

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 22
    radius: 11
    color: warn ? theme.dangerFill : on ? Qt.rgba(tone.r, tone.g, tone.b, 0.16) : theme.hover
    border.color: warn ? theme.dangerBorder : on ? Qt.rgba(tone.r, tone.g, tone.b, 0.6) : theme.border
    Label {
        id: label
        anchors.centerIn: parent
        text: parent.text
        color: parent.warn ? theme.dangerText : parent.on ? theme.accent : theme.textMuted
        font.pixelSize: 11
    }
}

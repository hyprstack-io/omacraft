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
    color: warn ? "#2a1416" : on ? Qt.rgba(tone.r, tone.g, tone.b, 0.16) : "#1d1d21"
    border.color: warn ? "#6b2a2f" : on ? Qt.rgba(tone.r, tone.g, tone.b, 0.6) : "#2c2c32"
    Label {
        id: label
        anchors.centerIn: parent
        text: parent.text
        color: parent.warn ? "#ffb4b4" : parent.on ? theme.accent : "#9a9aa3"
        font.pixelSize: 11
    }
}

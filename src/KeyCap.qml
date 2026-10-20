import QtQuick
import QtQuick.Controls

// A key, as shown next to the control it triggers.
Rectangle {
    property string text
    property color tint: theme.textMuted

    implicitWidth: Math.max(22, label.implicitWidth + 12)
    implicitHeight: 20
    radius: 4
    color: "transparent"
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.4)

    Label {
        id: label
        anchors.centerIn: parent
        text: parent.text
        color: parent.tint
        font.pixelSize: 11
        font.family: "monospace"
    }
}

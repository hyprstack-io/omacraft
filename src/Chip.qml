import QtQuick
import QtQuick.Controls

// A choice among a few, shown all at once so nothing drops out of view.
Rectangle {
    id: chip
    property string text
    property bool chosen: false
    property bool dimmed: false
    signal clicked()

    readonly property color tone: Qt.color(theme.accent)

    implicitWidth: label.implicitWidth + 22
    implicitHeight: 30
    radius: 7
    opacity: dimmed ? 0.45 : 1
    color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.16) : hover.hovered ? "#1d1d21" : "#111113"
    border.color: chosen ? theme.accent : "#26262b"

    Label {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.chosen ? theme.accent : "#d6d6da"
        font.pixelSize: 12
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.clicked() }
}

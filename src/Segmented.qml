import QtQuick
import QtQuick.Controls

// A few views of one tab, side by side in a pill, the chosen one filled.
// model: [{ id, name }].
Rectangle {
    id: seg
    property var model: []
    property string current
    signal picked(string id)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 34
    radius: 9
    color: theme.sunken
    border.color: theme.border

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: seg.model
            Rectangle {
                id: option
                required property var modelData
                readonly property bool on: seg.current === modelData.id
                width: optionLabel.implicitWidth + 24
                height: 28
                radius: 7
                color: on ? theme.accent : optionHover.hovered ? theme.hover : "transparent"
                Label {
                    id: optionLabel
                    anchors.centerIn: parent
                    text: option.modelData.name
                    color: option.on ? theme.accentForeground : theme.textSoft
                    font.pixelSize: 12
                    font.weight: option.on ? Font.DemiBold : Font.Normal
                }
                HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: seg.picked(option.modelData.id) }
            }
        }
    }
}

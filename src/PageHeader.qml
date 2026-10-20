import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A page's title, what it's for, and its actions on the right.
RowLayout {
    property string title
    property string subtitle
    property string glyph
    default property alias actions: actionRow.data

    Layout.fillWidth: true
    spacing: 12

    readonly property color tone: Qt.color(theme.accent)

    Rectangle {
        width: 34; height: 34; radius: 9
        color: Qt.rgba(tone.r, tone.g, tone.b, 0.14)
        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.5)
        Label {
            anchors.centerIn: parent
            text: glyph
            color: theme.accent
            font.pixelSize: 16
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Label { text: title; color: theme.text; font.pixelSize: 19; font.weight: Font.DemiBold }
        Label {
            Layout.fillWidth: true
            text: subtitle
            color: theme.textMuted
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
    RowLayout {
        id: actionRow
        spacing: 8
    }
}

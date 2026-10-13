import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One setting: a small caption, the control, and a line on what it does.
ColumnLayout {
    property string label
    property string hint
    property string key
    default property alias content: holder.data

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: label.toUpperCase()
            color: "#8a8a93"
            font.pixelSize: 11
            font.letterSpacing: 1.2
            font.weight: Font.DemiBold
        }
        Item { Layout.fillWidth: true }
        KeyCap { visible: key !== ""; text: key }
    }

    ColumnLayout {
        id: holder
        Layout.fillWidth: true
        spacing: 6
    }

    Label {
        visible: hint !== ""
        text: hint
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: "#74747d"
        font.pixelSize: 12
        textFormat: Text.StyledText
    }
}

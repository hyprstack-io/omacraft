import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// An on/off setting with a line on what it does.
RowLayout {
    property string label
    property string hint
    property alias checked: toggle.checked
    signal toggled(bool on)

    Layout.fillWidth: true
    spacing: 10
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Label { text: label; color: "white" }
        Label {
            visible: hint !== ""
            Layout.fillWidth: true
            text: hint
            color: "#74747d"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
    Switch {
        id: toggle
        focusPolicy: Qt.NoFocus
        onToggled: parent.toggled(checked)
    }
}

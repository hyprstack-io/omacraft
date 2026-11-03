import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Asks before something that's hard to take back. Enter confirms, Esc keeps
// going; the window wires the keys, so they work wherever the focus is.
Rectangle {
    id: confirm
    property string heading
    property string body
    property string action
    property string keepText: "Keep going"
    signal accepted()
    signal rejected()

    anchors.fill: parent
    visible: false
    color: "#cc000000"
    z: 50

    MouseArea { anchors.fill: parent; onClicked: confirm.rejected() }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(460, parent.width - 40)
        height: confirmColumn.implicitHeight + 44
        radius: 12
        color: theme.raised
        border.color: theme.borderStrong
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            id: confirmColumn
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12
            Label { text: confirm.heading; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
            Label { Layout.fillWidth: true; text: confirm.body; textFormat: Text.PlainText; color: theme.textSoft; wrapMode: Text.WordWrap }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Item { Layout.fillWidth: true }
                Button { text: confirm.keepText; flat: true; focusPolicy: Qt.NoFocus; onClicked: confirm.rejected() }
                KeyCap { text: "Esc" }
                Button {
                    text: confirm.action
                    focusPolicy: Qt.NoFocus
                    Material.background: theme.danger
                    Material.foreground: "white"
                    onClicked: confirm.accepted()
                }
                KeyCap { text: "Enter" }
            }
        }
    }
}

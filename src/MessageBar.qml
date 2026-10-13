import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// What went wrong, or what just happened, at the top of a page. Esc or the
// button dismisses it.
Rectangle {
    id: bar
    property string error
    property string notice
    signal dismissed()

    readonly property bool bad: error !== ""
    readonly property color tone: Qt.color(theme.accent)

    Layout.fillWidth: true
    visible: error !== "" || notice !== ""
    implicitHeight: row.implicitHeight + 18
    radius: 8
    color: bad ? "#2a1416" : Qt.rgba(tone.r, tone.g, tone.b, 0.10)
    border.color: bad ? "#6b2a2f" : Qt.rgba(tone.r, tone.g, tone.b, 0.45)

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 9
        anchors.leftMargin: 14
        spacing: 10
        Label {
            Layout.fillWidth: true
            text: bar.bad ? bar.error : bar.notice
            color: bar.bad ? "#ffb4b4" : "white"
            wrapMode: Text.WordWrap
        }
        Button {
            text: "Dismiss"
            flat: true
            focusPolicy: Qt.NoFocus
            onClicked: bar.dismissed()
        }
    }
}

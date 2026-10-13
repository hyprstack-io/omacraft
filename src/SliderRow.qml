import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A number set with a slider. It reports the value when let go, so each
// change is one step in the plugin's undo history, not hundreds.
RowLayout {
    id: row
    property string label
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property real value: 0
    property int decimals: 2
    property string suffix: ""
    signal moved(real value)

    Layout.fillWidth: true
    spacing: 10

    Label {
        Layout.preferredWidth: 120
        text: row.label
        color: "#d6d6da"
        elide: Text.ElideRight
    }
    Slider {
        id: slider
        Layout.fillWidth: true
        from: row.from
        to: row.to
        stepSize: row.stepSize
        value: row.value
        focusPolicy: Qt.NoFocus
        onPressedChanged: if (!pressed && Math.abs(value - row.value) > 1e-9) row.moved(value)
    }
    Label {
        Layout.preferredWidth: 52
        horizontalAlignment: Text.AlignRight
        text: slider.value.toFixed(row.decimals) + row.suffix
        color: theme.accent
        font.family: "monospace"
    }
}

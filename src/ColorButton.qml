import QtQuick
import QtQuick.Controls

// A swatch of the current colour that opens the full colour wheel. `value`
// is a #rrggbb or anything else (a theme colour's name, "theme"), which the
// wheel starts from as `fallback`.
Rectangle {
    id: button
    property string value
    property color fallback: theme.accent
    property string title: "Pick a colour"
    signal picked(string hex)

    readonly property bool isHex: /^#[0-9a-fA-F]{6}$/.test(String(value))

    implicitWidth: 34
    implicitHeight: 28
    radius: 7
    color: hover.hovered ? theme.hover : theme.inset
    border.color: wheel.opened ? theme.accent : theme.border

    // A conic hint of the wheel behind the current colour.
    Rectangle {
        anchors.centerIn: parent
        width: 18; height: 18; radius: 9
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#ff5555" }
            GradientStop { position: 0.33; color: "#55ff55" }
            GradientStop { position: 0.66; color: "#5599ff" }
            GradientStop { position: 1.0; color: "#ff55ff" }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 10; height: 10; radius: 5
            color: button.isHex ? button.value : button.fallback
            border.color: "#80000000"
        }
    }

    ToolTip.visible: hover.hovered
    ToolTip.text: "Colour wheel…"
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: wheel.openWith(button.isHex ? button.value : wheel.toHex(button.fallback)) }

    ColorPicker {
        id: wheel
        title: button.title
        onPicked: hex => button.picked(hex)
    }
}

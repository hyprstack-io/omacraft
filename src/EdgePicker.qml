import QtQuick
import QtQuick.Controls

// A small screen: click the edge something goes on.
Item {
    id: picker
    property var edges: ["top", "bottom", "left", "right"]
    property string current
    signal picked(string edge)

    implicitWidth: 132
    implicitHeight: 84

    Rectangle {
        id: monitor
        anchors.fill: parent
        anchors.margins: 6
        radius: 6
        color: theme.sunken
        border.color: theme.borderStrong
        Label { anchors.centerIn: parent; text: "screen"; color: theme.textFaint; font.pixelSize: 10 }
    }
    Repeater {
        model: picker.edges
        Rectangle {
            id: edgeBar
            required property string modelData
            readonly property bool on: picker.current === modelData
            readonly property bool horizontal: modelData === "top" || modelData === "bottom"
            x: modelData === "right" ? monitor.x + monitor.width - width : monitor.x + (horizontal ? 10 : 0)
            y: modelData === "bottom" ? monitor.y + monitor.height - height : monitor.y + (horizontal ? 0 : 10)
            width: horizontal ? monitor.width - 20 : 10
            height: horizontal ? 10 : monitor.height - 20
            radius: 3
            color: on ? theme.accent : edgeHover.hovered ? theme.textMuted : theme.border
            HoverHandler { id: edgeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: picker.picked(edgeBar.modelData) }
            ToolTip.visible: edgeHover.hovered
            ToolTip.text: edgeBar.modelData.charAt(0).toUpperCase() + edgeBar.modelData.slice(1)
        }
    }
}

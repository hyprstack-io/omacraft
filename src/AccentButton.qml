import QtQuick
import QtQuick.Controls

// The page's main action, filled with the theme accent, drawn like
// hyprbuildz's Build button so it looks the same in every renderer.
Rectangle {
    id: button
    property string text
    signal clicked()

    readonly property color tone: Qt.color(theme.accent)

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 36
    radius: 8
    opacity: enabled ? 1 : 0.4
    color: hover.hovered && enabled ? Qt.lighter(tone, 1.08) : tone

    Label {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: theme.accentForeground
        font.weight: Font.DemiBold
    }
    HoverHandler { id: hover; cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: button.enabled; onTapped: button.clicked() }
}

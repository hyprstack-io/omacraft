import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One design or animation to pick, shown as a still of the keyboard.
Rectangle {
    id: tile
    property string mode
    property var preset
    property bool chosen: false
    signal picked()

    readonly property color tone: Qt.color(theme.accent)

    implicitHeight: column.implicitHeight + 16
    radius: 10
    color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : hover.hovered ? theme.hover : theme.inset
    border.color: chosen ? theme.accent : theme.border
    border.width: chosen ? 2 : 1

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        KeyboardView {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 6 / 15
            labels: false
            glow: false
            // Re-rendered when the theme or the scene's colours change.
            colors: (lights.themeColors, lights.followTheme, lights.vivid, lights.word, lights.thumbnail(tile.mode, tile.preset.id))
        }
        Label {
            Layout.fillWidth: true
            text: tile.preset.name
            color: tile.chosen ? theme.accent : theme.text
            font.weight: Font.DemiBold
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Label {
            Layout.fillWidth: true
            text: tile.preset.description
            color: theme.textDim
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    ToolTip.visible: hover.hovered
    ToolTip.delay: 600
    ToolTip.text: tile.preset.description
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.picked() }
}

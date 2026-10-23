import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One theme, look, colour scheme or layout to pick, drawn as the bar it
// would make. Hovering shows it on the page's stage; a click applies it.
Rectangle {
    id: tile
    property string title
    property string subtitle
    property string tag
    property var cfg
    property var swatches: []
    property bool chosen: false
    property bool removable: false
    property bool exportable: false
    property bool labels: false
    signal picked()
    signal previewWanted(bool on)
    signal removeRequested()
    signal exportRequested()

    readonly property color tone: Qt.color(theme.accent)
    readonly property bool hovered: hover.hovered

    radius: 10
    color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : hovered ? theme.hover : theme.inset
    border.color: chosen ? theme.accent : hovered ? theme.borderStrong : theme.border
    border.width: chosen ? 2 : 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 6

        // The bar on a sliver of its own background, as it would sit on screen.
        Rectangle {
            id: strip
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 7
            clip: true
            readonly property color back: bar.themeColors.background || "#1a1b26"
            readonly property color glow: bar.themeColors.accent || "#7aa2f7"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.darker(strip.back, 1.25) }
                GradientStop { position: 1; color: Qt.tint(strip.back, Qt.rgba(strip.glow.r, strip.glow.g, strip.glow.b, 0.14)) }
            }
            BarPreview {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                cfg: tile.cfg
                themeColors: bar.themeColors
                labels: tile.labels
                segH: 22
                fontPx: 11
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Label {
                Layout.fillWidth: true
                text: tile.title
                color: tile.chosen ? theme.accent : theme.text
                font.weight: Font.DemiBold
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Label {
                visible: tile.tag !== "" || tile.chosen
                Layout.maximumWidth: tile.width * 0.42
                text: tile.chosen ? "in use" : tile.tag
                color: tile.chosen ? theme.accent : theme.textFaint
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Row {
                visible: tile.swatches.length > 0
                spacing: 2
                Repeater {
                    model: tile.swatches
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: index === 0 ? 14 : 10
                        height: 10
                        radius: 2
                        color: modelData
                        border.color: Qt.rgba(0.5, 0.5, 0.5, 0.35)
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                text: tile.subtitle
                color: theme.textDim
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    // Your own themes can go, or go out as a file.
    Row {
        visible: tile.hovered && (tile.removable || tile.exportable)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        spacing: 2
        ToolButton {
            visible: tile.exportable
            text: "\u{f0207}"
            implicitWidth: 26; implicitHeight: 26
            focusPolicy: Qt.NoFocus
            font.pixelSize: 13
            onClicked: tile.exportRequested()
            ToolTip.visible: hovered
            ToolTip.text: "Export (copies it too)"
        }
        ToolButton {
            visible: tile.removable
            text: "\u{f0a7a}"
            implicitWidth: 26; implicitHeight: 26
            focusPolicy: Qt.NoFocus
            font.pixelSize: 13
            onClicked: tile.removeRequested()
            ToolTip.visible: hovered
            ToolTip.text: "Delete this theme"
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: tile.previewWanted(hovered)
    }
    TapHandler { onTapped: tile.picked() }
}

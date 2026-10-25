import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One plugin on the landing page: its glyph lit while it runs, what it is,
// and its power switch (or Install, when it isn't there yet).
Rectangle {
    id: tile

    property var info: ({})
    property bool chosen: false
    property bool busy: false
    signal picked()
    signal switched()
    signal install()
    signal open()

    readonly property bool installed: info.installed === true
    readonly property bool on: info.enabled === true
    readonly property bool warn: info.state === "Broken link" || info.state === "Not found by the shell"
                                 || (info.duplicates || []).length > 0
    readonly property color tone: Qt.color(theme.accent)

    implicitHeight: 172
    radius: 14
    color: hover.hovered ? theme.hover : theme.card
    border.width: chosen ? 2 : 1
    border.color: chosen ? theme.accent : warn ? theme.warningBorder : theme.border
    opacity: installed ? 1 : 0.78
    Behavior on color { ColorAnimation { duration: 120 } }

    // A wash of the accent from the corner while it runs.
    Rectangle {
        anchors.fill: parent
        anchors.margins: tile.border.width
        radius: tile.radius - 1
        opacity: tile.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(tile.tone.r, tile.tone.g, tile.tone.b, 0.13) }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: tile.picked() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                implicitWidth: 42
                implicitHeight: 42
                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: Qt.rgba(tile.tone.r, tile.tone.g, tile.tone.b, tile.on ? 0.2 : 0.05)
                    border.color: tile.on ? Qt.rgba(tile.tone.r, tile.tone.g, tile.tone.b, 0.7) : theme.border
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Label {
                    anchors.centerIn: parent
                    text: tile.info.glyph || ""
                    color: tile.on ? theme.accent : theme.textMuted
                    font.pixelSize: 20
                }
                // The power light, breathing while it runs.
                Rectangle {
                    width: 10; height: 10; radius: 5
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -3
                    border.width: 2
                    border.color: theme.card
                    color: !tile.installed ? theme.textFaint : tile.warn ? theme.warning : tile.on ? theme.success : theme.textDim
                    SequentialAnimation on opacity {
                        running: tile.on && tile.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 1100; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    Layout.fillWidth: true
                    text: tile.info.name || ""
                    color: theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: tile.info.state || ""
                    color: tile.warn || tile.info.barIcons > 0 ? theme.warningText : tile.on ? theme.accent : theme.textDim
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: tile.info.summary || ""
            color: theme.textSoft
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            verticalAlignment: Text.AlignTop
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // The power switch: a long pill with ON / OFF in it.
            Rectangle {
                id: power
                visible: tile.installed
                implicitWidth: 74
                implicitHeight: 28
                radius: 14
                readonly property bool usable: !tile.busy
                opacity: usable ? 1 : 0.5
                color: tile.on ? theme.accent : theme.sunken
                border.color: tile.on ? theme.accent : theme.borderStrong
                Behavior on color { ColorAnimation { duration: 160 } }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: tile.on ? 11 : parent.width - width - 11
                    text: tile.on ? "ON" : "OFF"
                    color: tile.on ? theme.accentForeground : theme.textDim
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
                Rectangle {
                    width: 22; height: 22; radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    x: tile.on ? parent.width - width - 3 : 3
                    color: tile.on ? theme.accentForeground : theme.textMuted
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
                HoverHandler { cursorShape: power.usable ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler {
                    enabled: power.usable
                    onTapped: { tile.picked(); tile.switched(); }
                }
            }

            AccentButton {
                visible: !tile.installed
                enabled: tile.info.canInstall === true && !tile.busy
                text: tile.info.canInstall ? "Install" : "Code not found"
                implicitHeight: 30
                onClicked: { tile.picked(); tile.install(); }
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "Open  ›"
                color: openHover.hovered ? theme.accent : theme.textMuted
                font.pixelSize: 12
                font.weight: Font.DemiBold
                HoverHandler { id: openHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: tile.open() }
            }
        }
    }
}

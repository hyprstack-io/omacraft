import QtQuick
import QtQuick.Controls

// The live stage at the top of a page: a strip of desktop in the Omarchy
// theme's own colours, with a window or two, and whatever the page draws on
// it (the bar, the dock, an animation, a build). A caption in the corner says
// what it shows; it lights up while a tile is being previewed.
Rectangle {
    id: stage

    property string caption
    property bool previewing: false
    // Keep the windows clear of something drawn along this edge.
    property string edge: "none"
    property real edgeSize: 0
    property bool windows: true
    // Room the caption leaves on the right and below.
    property real captionRight: 10
    property real captionBottom: 8
    default property alias content: holder.data

    readonly property var tc: bar.themeColors
    readonly property color accentColor: tc.accent || "#7aa2f7"
    readonly property color backColor: tc.background || "#1a1b26"
    readonly property color glowColor: tc.magenta || tc.color5 || "#bb9af7"

    radius: 12
    clip: true
    border.color: previewing ? theme.accent : theme.border
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.darker(stage.backColor, 1.25) }
        GradientStop { position: 0.55; color: Qt.tint(stage.backColor, Qt.rgba(stage.accentColor.r, stage.accentColor.g, stage.accentColor.b, 0.18)) }
        GradientStop { position: 1; color: Qt.tint(stage.backColor, Qt.rgba(stage.glowColor.r, stage.glowColor.g, stage.glowColor.b, 0.22)) }
    }

    // A window or two, so floating, transparency and motion read.
    Rectangle {
        visible: stage.windows
        x: stage.edge === "left" ? stage.edgeSize + 24 : 24
        y: stage.edge === "top" ? stage.edgeSize + 14 : 14
        width: Math.min(stage.width * 0.36, 420)
        height: stage.height - 28 - (stage.edge === "top" || stage.edge === "bottom" ? stage.edgeSize : 0)
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.25)
        border.color: Qt.rgba(1, 1, 1, 0.08)
    }
    Rectangle {
        visible: stage.windows
        x: stage.width - width - (stage.edge === "right" ? stage.edgeSize + 24 : 24)
        y: stage.edge === "top" ? stage.edgeSize + 14 : 14
        width: Math.min(stage.width * 0.3, 360)
        height: stage.height - 28 - (stage.edge === "top" || stage.edge === "bottom" ? stage.edgeSize : 0)
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.18)
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    Rectangle {
        visible: stage.caption !== ""
        anchors.right: parent.right
        anchors.rightMargin: stage.captionRight
        anchors.bottom: parent.bottom
        anchors.bottomMargin: stage.captionBottom
        implicitWidth: captionLabel.implicitWidth + 18
        implicitHeight: 24
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.45)
        Label {
            id: captionLabel
            anchors.centerIn: parent
            font.pixelSize: 11
            color: "#eeeeee"
            text: stage.caption
        }
    }
}

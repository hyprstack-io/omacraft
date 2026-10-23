import QtQuick
import QtQuick.Controls

// What OmaCraft folds into when it's closed or minimised: a tab on the edge
// of the screen. Click it to bring the window back; drag it anywhere round
// the edge and it stays there. Hovering shows a button that really quits.
Window {
    id: tabWindow

    signal restoreWanted()
    signal quitWanted()

    readonly property string edge: edgeTab.edge
    readonly property bool upright: edgeTab.vertical

    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    visible: false
    title: "OmaCraft"
    width: upright ? 46 : 150
    height: upright ? 150 : 46

    property point grab
    readonly property bool hovered: hover.hovered || dragger.active

    Rectangle {
        id: body
        anchors.fill: parent
        // Square on the side against the screen edge, round on the others.
        readonly property real r: 14
        topLeftRadius: tabWindow.edge === "left" || tabWindow.edge === "top" ? 0 : r
        bottomLeftRadius: tabWindow.edge === "left" || tabWindow.edge === "bottom" ? 0 : r
        topRightRadius: tabWindow.edge === "right" || tabWindow.edge === "top" ? 0 : r
        bottomRightRadius: tabWindow.edge === "right" || tabWindow.edge === "bottom" ? 0 : r
        readonly property color tone: Qt.color(theme.accent)
        color: tabWindow.hovered ? Qt.tint(theme.card, Qt.rgba(tone.r, tone.g, tone.b, 0.12)) : theme.card
        border.color: tabWindow.hovered ? theme.accent : theme.borderStrong
        border.width: 1.5
        Behavior on color { ColorAnimation { duration: 140 } }

        // Logo, name, and (on hover) quit, along the tab.
        Grid {
            anchors.centerIn: parent
            flow: tabWindow.upright ? Grid.TopToBottom : Grid.LeftToRight
            columns: tabWindow.upright ? 1 : 3
            rows: tabWindow.upright ? 3 : 1
            spacing: 8
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Rectangle {
                width: 26; height: 26; radius: 8
                color: theme.accent
                Label {
                    anchors.centerIn: parent
                    text: "◆"
                    color: theme.accentForeground
                    font.pixelSize: 13
                }
            }
            // Turned to read up the side edges.
            Item {
                width: tabWindow.upright ? name.implicitHeight : name.implicitWidth
                height: tabWindow.upright ? name.implicitWidth : name.implicitHeight
                Label {
                    id: name
                    anchors.centerIn: parent
                    rotation: tabWindow.edge === "left" ? 90 : tabWindow.edge === "right" ? -90 : 0
                    text: "OmaCraft"
                    color: theme.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
            Rectangle {
                width: 22; height: 22; radius: 11
                opacity: hover.hovered && !dragger.active ? 1 : 0
                color: quitHover.hovered ? theme.hover : "transparent"
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Label {
                    anchors.centerIn: parent
                    text: "\u{f0425}"
                    color: quitHover.hovered ? theme.accent : theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
                HoverHandler { id: quitHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { enabled: parent.opacity > 0; onTapped: tabWindow.quitWanted() }
            }
        }
    }

    HoverHandler { id: hover; cursorShape: dragger.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor }
    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onTapped: (point, button) => { if (!quitHover.hovered) tabWindow.restoreWanted(); }
    }
    DragHandler {
        id: dragger
        target: null
        dragThreshold: 4
        onActiveChanged: {
            if (active) tabWindow.grab = centroid.pressPosition;
            else edgeTab.save();
        }
        onCentroidChanged: if (active) edgeTab.dragTo(centroid.position, tabWindow.grab)
    }
}

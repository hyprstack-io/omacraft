import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omacraft

// The Plugin Suite's title: "OmaCraft" played through the Boot Splash
// page's intro effects (introReel renders them with omascii). It starts on a
// random one each launch and loops it; the arrows step through them, and
// autoplay moves on to the next each time one finishes. A click on the art
// plays it again from the start.
ColumnLayout {
    id: title

    property bool running: true
    property bool autoplay: false
    property int frame: 0

    readonly property var frames: introReel.frames
    // The intro, then its finished art held for the reel's hold frames.
    readonly property int length: frames.length + introReel.hold
    readonly property string shown: frames.length > 0 ? frames[Math.min(frame, frames.length - 1)] : introReel.still

    spacing: 8

    Connections {
        target: introReel
        function onFramesChanged() { title.frame = 0; }
    }

    Timer {
        interval: Math.max(10, Math.round(1000 / introReel.fps))
        repeat: true
        running: title.running && title.visible && title.frames.length > 0
        onTriggered: {
            if (title.frame + 1 < title.length) {
                title.frame++;
                return;
            }
            // Finished: the next one when autoplaying (once it's ready),
            // otherwise this one again.
            title.frame = 0;
            if (title.autoplay && !introReel.loading)
                introReel.next();
        }
    }

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        signal clicked()
        width: 30; height: 30; radius: 15
        color: arrowHover.hovered ? theme.hover : "transparent"
        border.color: arrowHover.hovered ? theme.accent : theme.border
        opacity: introReel.available ? 1 : 0.3
        Label {
            anchors.centerIn: parent
            text: arrow.glyph
            color: arrowHover.hovered ? theme.accent : theme.textMuted
            font.pixelSize: 18
        }
        HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: introReel.available; onTapped: arrow.clicked() }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        spacing: 14

        Arrow {
            glyph: "‹"
            Layout.alignment: Qt.AlignVCenter
            onClicked: introReel.previous()
        }

        // Tall enough for the tallest frame seen, so the arrows don't jump.
        Item {
            id: stage
            Layout.fillWidth: true
            Layout.maximumWidth: art.naturalWidth * 1.4
            property real tallest: 0
            readonly property real fit: Math.min(1.4, width / Math.max(1, art.naturalWidth))
            implicitHeight: Math.max(60, tallest)
            onFitChanged: tallest = art.naturalHeight * fit

            AsciiView {
                id: art
                anchors.centerIn: parent
                html: title.shown
                color: theme.text
                fontFamily: "monospace"
                pixelSize: 14
                zoom: stage.fit
                onNaturalHeightChanged: stage.tallest = Math.max(stage.tallest, naturalHeight * stage.fit)
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: title.frame = 0 }
        }

        Arrow {
            glyph: "›"
            Layout.alignment: Qt.AlignVCenter
            onClicked: introReel.next()
        }
    }

    // Which intro this is, and autoplay.
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 10
        visible: introReel.available

        Label {
            text: (introReel.loading ? "building " : "") + introReel.effect
                  + "  " + (introReel.index + 1) + "/" + introReel.effects.length
            color: theme.textDim
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
        }
        Rectangle {
            id: autoButton
            implicitWidth: autoRow.implicitWidth + 20
            implicitHeight: 24
            radius: 12
            color: title.autoplay ? Qt.rgba(tone.r, tone.g, tone.b, 0.16) : autoHover.hovered ? theme.hover : "transparent"
            border.color: title.autoplay ? theme.accent : theme.border
            readonly property color tone: Qt.color(theme.accent)
            RowLayout {
                id: autoRow
                anchors.centerIn: parent
                spacing: 6
                Label {
                    text: title.autoplay ? "\u{f03e4}" : "\u{f040a}"
                    color: title.autoplay ? theme.accent : theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
                Label {
                    text: title.autoplay ? "Autoplay on" : "Autoplay"
                    color: title.autoplay ? theme.accent : theme.textMuted
                    font.pixelSize: 11
                }
            }
            HoverHandler { id: autoHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: title.autoplay = !title.autoplay }
        }
    }
}

import QtQuick
import QtQuick.Controls

// What happens as the machine sits untouched, to scale: the time runs left to
// right, and each thing that happens is a pin on it.
Item {
    id: line

    property int screensaver: 0
    property int lock: 0
    property int blank: 0

    readonly property int blankAt: lock > 0 ? lock + blank : 0
    readonly property real span: Math.max(60, screensaver, blankAt) * 1.08
    readonly property var pins: [
        { at: 0, glyph: "\u{f037d}", name: "Last touch", tone: theme.textMuted },
        { at: screensaver, glyph: "\u{f1104}", name: "Screensaver", tone: theme.accent, off: screensaver === 0 },
        { at: lock, glyph: "\u{f033e}", name: "Locked", tone: theme.accent, off: lock === 0 },
        { at: blankAt, glyph: "\u{f0425}", name: "Display off", tone: theme.textSoft, off: lock === 0 }
    ].filter(pin => !pin.off)

    function clockTime(seconds) {
        if (seconds === 0) return "now";
        if (seconds < 60) return seconds + " s";
        const minutes = Math.floor(seconds / 60);
        const rest = seconds % 60;
        return minutes + " min" + (rest > 0 ? " " + rest + " s" : "");
    }

    implicitHeight: 104

    Rectangle {
        id: track
        y: 42
        width: parent.width
        height: 4
        radius: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: theme.border }
            GradientStop { position: 1; color: theme.accent }
        }
    }
    Repeater {
        model: line.pins
        delegate: Item {
            id: pin
            required property var modelData
            required property int index
            readonly property real centre: 6 + (line.width - 12) * modelData.at / line.span
            // A pin crowding the one before gives up its icon and drops its
            // words a line, so nothing lands on top of anything.
            readonly property bool crowded: index > 0 && centre - (6 + (line.width - 12) * line.pins[index - 1].at / line.span) < 150
            anchors.fill: parent

            Label {
                visible: !pin.crowded
                x: pin.centre - width / 2
                y: 14
                text: pin.modelData.glyph
                color: pin.modelData.tone
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }
            Rectangle {
                x: pin.centre - 6
                y: 38
                width: 12; height: 12; radius: 6
                color: theme.card
                border.color: pin.modelData.tone
                border.width: 2
            }
            Label {
                x: Math.max(0, Math.min(line.width - width, pin.centre - width / 2))
                y: pin.crowded ? 72 : 56
                text: pin.modelData.name + " · " + line.clockTime(pin.modelData.at)
                color: theme.textMuted
                font.pixelSize: 10
            }
        }
    }
}

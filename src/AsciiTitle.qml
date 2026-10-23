import QtQuick
import "OmaCraftArt.js" as Art

// "OmaCraft" in TheDraw block art, drawn cell by cell rather than as text so
// the blocks meet without the font's line gaps. It decodes out of static
// column by column, then a light runs through it now and then; a click
// plays it again. Outlines (█ ▀ ▄) take the text colour, shading (▓ ▒ ░)
// the accent, and the shadow rows sink into the page.
Item {
    id: title

    property bool running: true
    // The widest a cell may get; the art shrinks to fit narrower space.
    property real maxCell: 11

    readonly property int cols: Art.rows[0].length
    readonly property int rowCount: Art.rows.length
    readonly property real cell: Math.max(3, Math.min(maxCell, width / cols))
    readonly property real decodeMs: 1500
    readonly property real sweepEvery: 5200

    implicitWidth: cols * maxCell
    implicitHeight: rowCount * cell * 2

    property real clock: 0
    property real started: 0

    function replay() { title.started = title.clock; }

    // Where each column settles during the decode, staggered a little per
    // row so the edge is ragged rather than a ruler.
    function settleAt(row, col) {
        return 90 + col * 17 + ((row * 37 + col * 11) % 7) * 22;
    }

    FrameAnimation {
        running: title.running && title.visible
        onTriggered: {
            title.clock += frameTime * 1000;
            canvas.requestPaint();
        }
    }

    TapHandler { onTapped: title.replay() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    Canvas {
        id: canvas
        anchors.horizontalCenter: parent.horizontalCenter
        width: title.cols * title.cell
        height: title.rowCount * title.cell * 2
        renderStrategy: Canvas.Cooperative

        readonly property color ink: theme.text
        readonly property color accent: theme.accent

        onInkChanged: requestPaint()
        onAccentChanged: requestPaint()
        onWidthChanged: requestPaint()

        function rgba(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
                   + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
        }
        function mix(a, b, t) {
            return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = title.cell, h = title.cell * 2;
            const t = title.clock - title.started;
            const noise = "▓▒░▀▄█";
            // The light: a slanted band crossing once per sweepEvery after
            // the decode, about a tenth of the art wide.
            const sweepT = (t - title.decodeMs) % title.sweepEvery;
            const band = t > title.decodeMs ? (sweepT / 1400) * (title.cols + 30) - 15 : -999;

            for (let r = 0; r < title.rowCount; r++) {
                const line = Art.rows[r];
                const shadow = r >= Art.shadowFrom;
                for (let c = 0; c < title.cols; c++) {
                    let ch = line[c];
                    if (ch === " ") continue;
                    const settle = title.settleAt(r, c);
                    if (t < settle - 420) continue;
                    let scrambling = t < settle;
                    if (scrambling)
                        ch = noise[Math.floor((t / 60 + c * 7 + r * 3)) % noise.length];

                    // Outline or shading, and how strong.
                    const solid = ch === "█" || ch === "▀" || ch === "▄";
                    let alpha = ch === "▓" ? 0.9 : ch === "▒" ? 0.62 : ch === "░" ? 0.34 : 1;
                    let color = solid ? canvas.ink : canvas.accent;
                    if (shadow) {
                        color = canvas.accent;
                        alpha *= 0.55 - (r - Art.shadowFrom) * 0.12;
                    }
                    if (scrambling) {
                        color = canvas.accent;
                        alpha *= 0.35;
                    } else {
                        const d = Math.abs(c - r * 1.5 - band);
                        if (d < 6)
                            color = canvas.mix(color, Qt.rgba(1, 1, 1, 1), (1 - d / 6) * (shadow ? 0.3 : 0.75));
                    }
                    ctx.fillStyle = canvas.rgba(color, alpha);

                    const x = c * w, y = r * h;
                    // A hair of overlap so neighbouring blocks don't show seams.
                    if (ch === "▀")
                        ctx.fillRect(x, y, w + 0.5, h / 2 + 0.5);
                    else if (ch === "▄")
                        ctx.fillRect(x, y + h / 2, w + 0.5, h / 2 + 0.5);
                    else
                        ctx.fillRect(x, y, w + 0.5, h + 0.5);
                }
            }
        }
    }
}

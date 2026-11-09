import QtQuick
import "WallPickerArt.js" as Art

// "SELECT WALLPAPER" in TheDraw balistcx (the font of OMACRAFT, HYPRSTACK and
// HYPRVYZR), drawn cell by cell so the blocks meet without the font's line
// gaps. It plays as the HyprVYZR carousel's title does: the art is cut into
// tiles that land in a scattered order, each decrypting out of glyph noise
// before it settles, then a slanted light sweeps through now and then and a
// faint scanline drifts down. A click replays it.
//
// Colours come from the picker: the wallpaper's border colours run across
// the letters, the bright middle row is the ink, and the half-block shadow
// sinks into the page.
Item {
    id: title

    property bool running: true
    property color ink: "#ffffff"
    property color accent: "#7aa2f7"
    property color accent2: "#bb9af7"
    // The widest a cell may get; the art shrinks to fit narrower space.
    property real maxCell: 8
    // Reduced motion: the art appears whole, with no sweep.
    property bool still: false

    readonly property int cols: Art.rows[0].length
    readonly property int rowCount: Art.rows.length
    readonly property real cell: Math.max(2, Math.min(maxCell, width > 0 ? width / cols : maxCell))
    readonly property int tileCols: 8
    readonly property int tileRows: 2
    readonly property real tileMs: 240
    readonly property real arriveMs: 1300
    readonly property real sweepEvery: 5600

    implicitWidth: cols * maxCell
    implicitHeight: rowCount * cell * 2

    property real clock: 0
    property real started: 0

    function replay() { title.started = title.clock; }

    // When a tile lands: a scattered but fixed order, so every play looks
    // the same and no two neighbours land together.
    function landsAt(row, col) {
        const tx = Math.floor(col / tileCols), ty = Math.floor(row / tileRows);
        const tiles = Math.ceil(cols / tileCols) * Math.ceil(rowCount / tileRows);
        const n = ty * Math.ceil(cols / tileCols) + tx;
        const order = (n * 37 + 11) % tiles;
        return order / tiles * arriveMs;
    }

    FrameAnimation {
        running: title.running && title.visible && !title.still
        onTriggered: {
            title.clock += frameTime * 1000;
            canvas.requestPaint();
        }
    }
    onStillChanged: canvas.requestPaint()

    TapHandler { onTapped: title.replay() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    Canvas {
        id: canvas
        anchors.horizontalCenter: parent.horizontalCenter
        width: title.cols * title.cell
        height: title.rowCount * title.cell * 2
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        Connections {
            target: title
            function onInkChanged() { canvas.requestPaint(); }
            function onAccentChanged() { canvas.requestPaint(); }
            function onAccent2Changed() { canvas.requestPaint(); }
        }

        function rgba(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
                   + Math.round(c.b * 255) + "," + Math.max(0, Math.min(1, a)).toFixed(3) + ")";
        }
        function mix(a, b, t) {
            return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = title.cell, h = title.cell * 2;
            const t = title.still ? 1e9 : title.clock - title.started;
            const noise = "▓▒░█▌▐/\\<>01";
            const done = title.arriveMs + title.tileMs;
            // The light: a slanted band crossing once per sweepEvery after
            // the art has arrived.
            const sweepT = (t - done) % title.sweepEvery;
            const band = !title.still && t > done ? (sweepT / 1500) * (title.cols + 40) - 20 : -999;
            // The scanline: one row-height of brightness drifting down.
            const scan = title.still ? -9 : ((t / 22) % (title.rowCount * h + 60)) - 30;

            for (let r = 0; r < title.rowCount; r++) {
                const line = Art.rows[r];
                for (let c = 0; c < title.cols; c++) {
                    let ch = line[c];
                    if (ch === " ") continue;
                    const lands = title.landsAt(r, c);
                    if (t < lands) continue;
                    const decrypting = t < lands + title.tileMs;
                    if (decrypting)
                        ch = noise[Math.floor(t / 45 + c * 7 + r * 13) % noise.length];

                    // Across the word, accent to accent-2.
                    let color = canvas.mix(title.accent, title.accent2, c / title.cols);
                    let alpha = 1;
                    if (ch === "█") color = title.ink;
                    else if (ch === "▓") alpha = 0.95;
                    else if (ch === "▒") alpha = 0.72;
                    else if (ch === "░") alpha = 0.42;
                    if (decrypting) {
                        color = title.accent;
                        alpha = 0.3 + 0.4 * ((lands + title.tileMs - t) / title.tileMs);
                    } else {
                        const d = Math.abs(c - r * 1.6 - band);
                        if (d < 7)
                            color = canvas.mix(color, title.ink, (1 - d / 7) * 0.8);
                        const y = r * h + h / 2;
                        if (Math.abs(y - scan) < h)
                            alpha = Math.min(1, alpha + 0.25 * (1 - Math.abs(y - scan) / h));
                    }

                    const x = c * w, y0 = r * h;
                    if (ch === "▀") {
                        // The shadow under a joined letter: its top half.
                        ctx.fillStyle = canvas.rgba(title.accent2, decrypting ? alpha * 0.5 : 0.32);
                        ctx.fillRect(x, y0, w + 0.5, h / 2 + 0.5);
                    } else if (ch === "▌") {
                        ctx.fillStyle = canvas.rgba(color, alpha);
                        ctx.fillRect(x, y0, w / 2 + 0.5, h + 0.5);
                    } else if (ch === "▐") {
                        // The cast shadow, sunk into the page.
                        ctx.fillStyle = canvas.rgba(title.accent2, decrypting ? alpha * 0.5 : 0.32);
                        ctx.fillRect(x + w / 2, y0, w / 2 + 0.5, h + 0.5);
                    } else if (decrypting && ch !== "█" && ch !== "▓" && ch !== "▒" && ch !== "░" && ch !== "▀") {
                        // Noise that isn't a block: a thin glyph-like bar.
                        ctx.fillStyle = canvas.rgba(color, alpha * 0.8);
                        ctx.fillRect(x + w * 0.3, y0 + h * 0.2, w * 0.4, h * 0.6);
                    } else {
                        ctx.fillStyle = canvas.rgba(color, alpha);
                        // A hair of overlap so neighbouring blocks don't show seams.
                        ctx.fillRect(x, y0, w + 0.5, h + 0.5);
                    }
                }
            }
        }
    }
}

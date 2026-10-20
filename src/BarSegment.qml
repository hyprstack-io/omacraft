import QtQuick
import QtQuick.Shapes

// One bar segment, drawn with the geometry omabar16's bar uses, so a preview
// looks like the bar: [pad | content | pad], less the overlap that lets a
// point sit in its neighbour's notch.
Item {
    id: seg

    property string kind: "arrow"      // arrow | slant | backslant | trapezoid | hex | round | block | leaf | tab | underline | none
    property string mode: "right"      // which way the point faces: right | left | both
    property color fill: "#888888"
    property color textColor: "#000000"
    property color outlineColor: "transparent"
    property real outline: 0
    property bool flatEdge: false
    property int h: 22
    property real depthFactor: 0.42
    property int gap: 1
    property int pad: 3
    property string glyph: ""
    property string glyphFont: "JetBrainsMono Nerd Font"
    property string label: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontPx: 11
    property real blockRadius: 0
    property real itemOpacity: 1
    property bool selected: false
    property bool hovered: false
    property color selectColor: theme.accent
    property bool interactive: false
    // A fixed width (a spacer), or 0 to fit the content.
    property real fixedWidth: 0
    signal clicked()

    readonly property int depth: kind === "arrow" ? Math.max(2, Math.round(h * depthFactor))
        : kind === "hex" ? Math.max(2, Math.round(h * depthFactor * 0.6))
        : (["slant", "backslant", "trapezoid"].indexOf(kind) >= 0 ? Math.max(2, Math.round(h * 0.32)) : 0)
    readonly property bool polygon: ["arrow", "slant", "backslant", "trapezoid", "hex"].indexOf(kind) >= 0
    readonly property bool box: ["round", "block", "leaf", "tab", "underline"].indexOf(kind) >= 0
    readonly property int notch: kind === "arrow" && flatEdge ? 0 : depth
    readonly property int basePad: kind === "round" ? Math.round(h * 0.3) : kind === "none" ? Math.max(pad, 5) : pad
    readonly property int padL: (mode === "right" ? notch : depth) + basePad
    readonly property int padR: (mode === "left" ? notch : depth) + basePad
    readonly property real contentWidth: fixedWidth > 0 ? fixedWidth : content.implicitWidth
    readonly property real base: contentWidth + padL + padR
    // Slants nest into their neighbours; trapezoids and hexagons stand apart.
    readonly property real overlap: kind === "trapezoid" || kind === "hex" ? -gap : depth - gap
    readonly property real pokeL: mode === "left" || mode === "both" ? overlap : 0
    readonly property real pokeR: mode === "right" || mode === "both" ? overlap : 0

    implicitWidth: base - pokeL - pokeR
    implicitHeight: h
    width: implicitWidth
    height: h
    opacity: itemOpacity

    readonly property var points: {
        const w = base, hh = h, d = depth, n = notch;
        if (kind === "slant") return [Qt.point(d, 0), Qt.point(w, 0), Qt.point(w - d, hh), Qt.point(0, hh)];
        if (kind === "backslant") return [Qt.point(0, 0), Qt.point(w - d, 0), Qt.point(w, hh), Qt.point(d, hh)];
        if (kind === "trapezoid") return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w - d, hh), Qt.point(d, hh)];
        if (kind === "hex" || mode === "both")
            return [Qt.point(d, 0), Qt.point(w - d, 0), Qt.point(w, hh / 2), Qt.point(w - d, hh), Qt.point(d, hh), Qt.point(0, hh / 2)];
        const pts = [Qt.point(0, 0), Qt.point(w - d, 0), Qt.point(w, hh / 2), Qt.point(w - d, hh), Qt.point(0, hh)];
        if (n > 0) pts.push(Qt.point(n, hh / 2));
        return pts;
    }

    Shape {
        id: poly
        visible: seg.polygon
        x: -seg.pokeL
        width: seg.base
        height: seg.h
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.x: poly.width / 2; xScale: seg.mode === "left" ? -1 : 1 }

        ShapePath {
            fillColor: seg.fill
            strokeColor: seg.outline > 0 ? seg.outlineColor : "transparent"
            strokeWidth: seg.outline > 0 ? seg.outline : -1
            PathPolyline { path: seg.points }
        }
    }

    Rectangle {
        readonly property real lineH: Math.max(2, Math.round(seg.h * 0.12))
        readonly property real baseR: seg.kind === "round" ? height / 2 : Math.min(seg.blockRadius, height / 2)
        visible: seg.box
        x: -seg.pokeL
        y: seg.kind === "underline" ? seg.h - lineH : 0
        width: seg.base
        height: seg.kind === "underline" ? lineH : seg.h
        radius: seg.kind === "underline" ? lineH / 2 : baseR
        topLeftRadius: seg.kind === "leaf" ? height / 2 : seg.kind === "tab" ? Math.min(10, height / 2) : radius
        bottomRightRadius: seg.kind === "leaf" ? height / 2 : seg.kind === "tab" ? 0 : radius
        topRightRadius: seg.kind === "leaf" ? Math.min(2, radius) : seg.kind === "tab" ? Math.min(10, height / 2) : radius
        bottomLeftRadius: seg.kind === "leaf" ? Math.min(2, radius) : seg.kind === "tab" ? 0 : radius
        color: seg.fill
        border.width: seg.kind !== "underline" && seg.outline > 0 ? seg.outline : 0
        border.color: seg.outlineColor
    }

    // The hover wash, as the bar shows it.
    Rectangle {
        visible: seg.hovered && seg.interactive
        x: -seg.pokeL + (seg.polygon ? seg.depth / 2 : 0)
        width: seg.base - (seg.polygon ? seg.depth : 0)
        height: seg.h
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.14)
    }

    Row {
        id: content
        x: -seg.pokeL + seg.padL + (seg.fixedWidth > 0 ? (seg.fixedWidth - implicitWidth) / 2 : 0)
        height: seg.h
        spacing: seg.label !== "" && seg.glyph !== "" ? Math.round(seg.fontPx * 0.5) : 0
        Text {
            visible: seg.glyph !== ""
            height: seg.h
            verticalAlignment: Text.AlignVCenter
            text: seg.glyph
            color: seg.textColor
            font.family: seg.glyphFont
            font.pixelSize: Math.round(seg.fontPx * 1.08)
        }
        Text {
            visible: seg.label !== ""
            height: seg.h
            verticalAlignment: Text.AlignVCenter
            text: seg.label
            color: seg.textColor
            font.family: seg.fontFamily
            font.pixelSize: seg.fontPx
        }
    }

    Rectangle {
        visible: seg.selected
        x: -seg.pokeL - 1
        y: -3
        width: seg.base + 2
        height: seg.h + 6
        radius: 5
        color: "transparent"
        border.width: 2
        border.color: seg.selectColor
    }

    HoverHandler {
        id: hover
        enabled: seg.interactive
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: seg.hovered = hovered
    }
    TapHandler {
        enabled: seg.interactive
        onTapped: seg.clicked()
    }
}

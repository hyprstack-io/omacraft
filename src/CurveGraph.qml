import QtQuick
import QtQuick.Shapes

// The shape of an animation curve: a bezier as it's drawn, a spring as the
// overshoot it settles from.
Item {
    id: graph
    property var curve: ({ type: "bezier", points: [[0.25, 0.1], [0.25, 1]] })
    property color color: theme.accent

    readonly property var springPoints: {
        if (curve.type !== "spring") return [];
        const k = Number(curve.stiffness) || 200, d = Number(curve.dampening) || 15, m = Number(curve.mass) || 1;
        const w0 = Math.sqrt(k / m), zeta = d / (2 * Math.sqrt(k * m)), out = [];
        for (let i = 0; i <= 40; i++) {
            const x = i / 40, tt = x * 1.2;
            const v = zeta < 1 ? 1 - Math.exp(-zeta * w0 * tt) * Math.cos(w0 * Math.sqrt(1 - zeta * zeta) * tt)
                               : 1 - Math.exp(-w0 * tt) * (1 + w0 * tt);
            out.push(Qt.point(x * width, height - Math.max(-0.2, Math.min(1.3, v)) * height * 0.75 - height * 0.12));
        }
        return out;
    }
    readonly property var p: curve.type === "bezier" && curve.points ? curve.points : [[0.25, 0.1], [0.25, 1]]
    readonly property real curveH: height * 0.75
    readonly property real curveTop: height * 0.12

    Rectangle { anchors.fill: parent; radius: 4; color: Qt.rgba(0, 0, 0, 0.18) }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: graph.color
            strokeWidth: 1.6
            fillColor: "transparent"
            startX: 0
            startY: graph.curveTop + graph.curveH
            PathCubic {
                x: graph.width; y: graph.curveTop
                control1X: graph.p[0][0] * graph.width; control1Y: graph.curveTop + graph.curveH - graph.p[0][1] * graph.curveH
                control2X: graph.p[1][0] * graph.width; control2Y: graph.curveTop + graph.curveH - graph.p[1][1] * graph.curveH
            }
        }
        visible: graph.curve.type !== "spring"
    }
    Shape {
        anchors.fill: parent
        visible: graph.curve.type === "spring"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: graph.color
            strokeWidth: 1.6
            fillColor: "transparent"
            PathPolyline { path: graph.springPoints }
        }
    }
}

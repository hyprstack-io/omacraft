import QtQuick
import QtQuick.Shapes

// What's drawn behind a popup: plain dimming, a vignette closing in from the
// corners, a spotlight on the middle, or an aurora of the accent drifting
// slowly. Drawn the same over the desktop and on OmaCraft's preview.
Item {
  id: back

  // dim, vignette, spotlight or aurora.
  property string style: "dim"
  property real dim: 0.55
  property color accent: "#7aa2f7"
  property color second: "#f7768e"
  property bool running: false

  function shade(a) { return Qt.rgba(0, 0, 0, Math.max(0, Math.min(1, a))) }
  function tinted(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  Rectangle {
    anchors.fill: parent
    color: back.shade(back.style === "dim" || back.style === "aurora" ? back.dim : back.dim * 0.45)
  }

  // A light or dark pool: from the middle of the screen out to its corners.
  Shape {
    anchors.fill: parent
    visible: back.style === "vignette" || back.style === "spotlight"
    ShapePath {
      strokeWidth: -1
      startX: 0; startY: 0
      fillGradient: RadialGradient {
        centerX: back.width / 2; centerY: back.height / 2
        focalX: back.width / 2; focalY: back.height / 2
        centerRadius: Math.max(back.width, back.height) * 0.62
        GradientStop { position: 0; color: back.style === "spotlight" ? back.tinted(back.accent, 0.26) : back.shade(0) }
        GradientStop { position: 0.55; color: back.style === "spotlight" ? back.shade(back.dim * 0.5) : back.shade(back.dim * 0.35) }
        GradientStop { position: 1; color: back.shade(Math.min(0.95, back.dim * 1.5)) }
      }
      PathLine { x: back.width; y: 0 }
      PathLine { x: back.width; y: back.height }
      PathLine { x: 0; y: back.height }
      PathLine { x: 0; y: 0 }
    }
  }

  // Two pools of colour on slow, unequal loops, so they never quite repeat.
  Item {
    id: aurora
    anchors.fill: parent
    visible: back.style === "aurora"
    clip: true
    property real t: 0
    NumberAnimation on t {
      from: 0; to: Math.PI * 2; duration: 24000; loops: Animation.Infinite
      running: back.running && back.style === "aurora"
    }
    Repeater {
      model: [{ size: 0.9, x: 0.28, y: 0.3, speed: 1, tone: 0 }, { size: 0.75, x: 0.72, y: 0.68, speed: 2, tone: 1 }]
      Shape {
        id: pool
        required property var modelData
        readonly property real d: aurora.width * modelData.size
        readonly property color tone: modelData.tone === 0 ? back.accent : back.second
        width: d; height: d
        x: aurora.width * (modelData.x + 0.08 * Math.sin(aurora.t * modelData.speed)) - d / 2
        y: aurora.height * (modelData.y + 0.1 * Math.cos(aurora.t * modelData.speed)) - d / 2
        ShapePath {
          strokeWidth: -1
          fillGradient: RadialGradient {
            centerX: pool.d / 2; centerY: pool.d / 2
            focalX: pool.d / 2; focalY: pool.d / 2
            centerRadius: pool.d / 2
            GradientStop { position: 0; color: back.tinted(pool.tone, 0.34) }
            GradientStop { position: 1; color: back.tinted(pool.tone, 0) }
          }
          PathAngleArc { centerX: pool.d / 2; centerY: pool.d / 2; radiusX: pool.d / 2; radiusY: pool.d / 2; startAngle: 0; sweepAngle: 360 }
        }
      }
    }
  }
}

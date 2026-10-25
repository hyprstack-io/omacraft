import QtQuick
import QtQuick.Shapes

// The border of the card in front, animated. The default is Burn My Windows'
// Border Trace: two comets in the active border's gradient chase round the
// slanted edge, each a bright head with a fading tail. The shell can't build
// a new shader, so every effect is drawn from strokes: a comet is a few
// dashed strokes sharing one head, a long faint dash under shorter, brighter
// ones. OmaCraft's Wallpapers page draws its previews with this same file.
//
//   effect  trace, orbit, rainbow, pulse, neon, marching, plain
Item {
  id: card

  property string effect: "trace"
  // The card's corners along its top and bottom edges, as the slices draw them.
  property real topLeft: 0
  property real topRight: width
  property real bottomRight: width
  property real bottomLeft: 0
  property color color1: "#33ccff"
  property color color2: "#00ff99"
  property bool running: true
  property real lineWidth: 3
  // 1 is the effect's own pace; 2 twice as fast.
  property real speed: 1

  readonly property real rightSide: Math.sqrt(height * height + Math.pow(topRight - bottomRight, 2))
  readonly property real leftSide: Math.sqrt(height * height + Math.pow(topLeft - bottomLeft, 2))
  readonly property real perimeter: (topRight - topLeft) + rightSide + (bottomRight - bottomLeft) + leftSide
  readonly property int lapMs: Math.round((effect === "orbit" ? 1800 : effect === "rainbow" ? 3400 : 2800) / Math.max(0.2, speed))

  readonly property bool comets: effect === "trace" || effect === "orbit" || effect === "rainbow"
  readonly property int cometCount: effect === "orbit" ? 4 : effect === "rainbow" ? 1 : 2

  // 0..1 round one lap (comets, marching) and one breath (pulse, neon).
  property real phase: 0
  NumberAnimation on phase {
    from: 0
    to: 1
    duration: card.effect === "pulse" || card.effect === "neon" ? Math.round(1800 / Math.max(0.2, card.speed)) : card.lapMs
    loops: Animation.Infinite
    running: card.running && card.effect !== "plain" && card.perimeter > 0
  }
  // Breathing, 0..1..0, for pulse and neon.
  readonly property real breath: 0.5 - 0.5 * Math.cos(phase * 2 * Math.PI)
  // Rainbow's colour, going once round the hues per lap.
  readonly property color hue: Qt.hsla(phase, 0.85, 0.62, 1)

  function tint(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }

  // The card's edge, for every stroke below.
  component Edge: ShapePath {
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    startX: card.topLeft; startY: 0
    PathLine { x: card.topRight; y: 0 }
    PathLine { x: card.bottomRight; y: card.height }
    PathLine { x: card.bottomLeft; y: card.height }
    PathLine { x: card.topLeft; y: 0 }
  }

  // ------------------------------------------------------------ comets

  // Tail to head: length (share of a lap), width (times lineWidth), opacity.
  readonly property var cometParts: [
    { length: 0.16, width: 4.0, alpha: 0.14 },
    { length: 0.30, width: 1.0, alpha: 0.30 },
    { length: 0.20, width: 1.0, alpha: 0.55 },
    { length: 0.11, width: 1.0, alpha: 0.85 },
    { length: 0.045, width: 1.4, alpha: 1.0 }
  ]
  readonly property real cometScale: effect === "orbit" ? 0.45 : effect === "rainbow" ? 1.4 : 1

  // Rainbow's trail: the whole edge, faintly, in the passing colour.
  Shape {
    anchors.fill: parent
    visible: card.effect === "rainbow"
    antialiasing: true
    Edge { strokeColor: card.tint(card.hue, 0.35); strokeWidth: card.lineWidth * 0.7 }
  }

  Repeater {
    model: card.comets ? card.cometCount * card.cometParts.length : 0

    Shape {
      id: stroke
      required property int index
      readonly property int comet: Math.floor(index / card.cometParts.length)
      readonly property var part: card.cometParts[index % card.cometParts.length]
      readonly property real width_: card.lineWidth * part.width
      readonly property real dash: Math.max(1, Math.min(0.9 / card.cometCount, part.length * card.cometScale) * card.perimeter)
      // Comets share the lap evenly; dashes are measured in stroke widths.
      readonly property real headAt: (card.phase + comet / card.cometCount) * card.perimeter
      readonly property real offset: (((dash - headAt) % card.perimeter) + card.perimeter) % card.perimeter
      readonly property color base: card.effect === "rainbow" ? card.hue : (comet % 2 ? card.color2 : card.color1)

      anchors.fill: parent
      antialiasing: true
      Edge {
        strokeColor: card.tint(stroke.base, stroke.part.alpha)
        strokeWidth: stroke.width_
        strokeStyle: ShapePath.DashLine
        dashPattern: [stroke.dash / stroke.width_, (card.perimeter - stroke.dash) / stroke.width_]
        dashOffset: stroke.offset / stroke.width_
      }
    }
  }

  // ------------------------------------------------------------ pulse, neon

  // Pulse breathes between the two colours, growing as it brightens. Neon
  // is a glow in layers round a bright line, swelling slowly.
  Repeater {
    model: card.effect === "neon" ? [
      { width: 5.0, alpha: 0.10 }, { width: 3.2, alpha: 0.18 }, { width: 2.0, alpha: 0.35 }, { width: 0.8, alpha: 1.0 }
    ] : card.effect === "pulse" ? [
      { width: 3.0, alpha: 0.25 }, { width: 1.0, alpha: 1.0 }
    ] : []

    Shape {
      required property var modelData
      anchors.fill: parent
      antialiasing: true
      Edge {
        readonly property real swell: card.effect === "neon" ? 0.75 + 0.5 * card.breath : 0.7 + 0.8 * card.breath
        strokeColor: card.effect === "neon"
          ? card.tint(modelData.alpha >= 1 ? Qt.lighter(card.color1, 1.25) : card.color1, modelData.alpha * (0.7 + 0.3 * card.breath))
          : card.tint(card.mix(card.color1, card.color2, card.breath), modelData.alpha * (0.55 + 0.45 * card.breath))
        strokeWidth: card.lineWidth * modelData.width * (modelData.alpha >= 1 ? 1 : swell)
      }
    }
  }

  // ------------------------------------------------------------ marching

  // Two colours of dashes marching round, one in each other's gaps.
  Repeater {
    model: card.effect === "marching" ? 2 : 0

    Shape {
      id: ants
      required property int index
      readonly property real dash: 14
      anchors.fill: parent
      antialiasing: true
      Edge {
        capStyle: ShapePath.FlatCap
        strokeColor: ants.index ? card.color2 : card.color1
        strokeWidth: card.lineWidth
        strokeStyle: ShapePath.DashLine
        dashPattern: [ants.dash / card.lineWidth, ants.dash / card.lineWidth]
        // Round the period of the pattern, so the lap loops without a jump.
        dashOffset: (ants.index * ants.dash - card.phase * Math.round(card.perimeter / 28) * 2 * ants.dash) / card.lineWidth
      }
    }
  }

  // ------------------------------------------------------------ plain

  Shape {
    anchors.fill: parent
    visible: card.effect === "plain"
    antialiasing: true
    Edge { strokeColor: card.color1; strokeWidth: card.lineWidth }
  }
}

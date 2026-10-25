import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../data/Presets.js" as P

// A scaled, faithful sketch of the bar for a given config. Used for the live
// header preview, every theme card and every layout card.
Item {
  id: mb

  property var cfg: ({ layout: { left: [], center: [], right: [] }, style: {}, centerAnchor: "" })
  property var themeColors: ({})
  property var defaults: ({ background: "#101315", foreground: "#cacccc", accent: "#cacccc" })
  property string selectedPart: ""
  property bool interactive: false
  property bool showLabels: false
  property int segH: 22
  property int fontPx: 11

  signal partClicked(string part)

  readonly property var style: cfg && cfg.style ? cfg.style : ({})
  readonly property var res: P.resolve(style, themeColors, defaults)
  readonly property string kind: style.shape ? style.shape : "none"
  readonly property int gap: style.gap === undefined ? 1 : style.gap
  readonly property int inset: style.inset === undefined ? 0 : style.inset
  readonly property int floatPx: style.float === undefined ? 0 : style.float
  readonly property int edge: style.edge === undefined ? (kind === "none" ? 8 : 0) : style.edge
  readonly property int barH: segH + 2 * inset + 6
  readonly property real natural: leftRow.width + centerRow.width + rightRow.width + edge * 2 + 48
  readonly property real fit: Math.min(1, mb.width / Math.max(1, natural))

  implicitHeight: (barH + 2 * floatPx) * fit
  height: implicitHeight

  function lane(name) {
    return cfg && cfg.layout && P.isList(cfg.layout[name]) ? cfg.layout[name] : []
  }

  function anchorIndex() {
    var l = lane("center")
    for (var i = 0; i < l.length; i++) if (l[i].id === cfg.centerAnchor) return i
    return -1
  }

  function modeFor(region, index) {
    if (kind !== "arrow") return "right"
    if (region === "right") return "left"
    if (region === "center") {
      var a = anchorIndex()
      if (a < 0) return "right"
      return index < a ? "left" : (index === a ? "both" : "right")
    }
    return "right"
  }

  component MiniSeg: SegmentShape {
    property var entry: ({ id: "" })
    property int idx: 0
    property string region: ""
    property int count: 0
    readonly property string moduleId: entry.id

    kind: mb.kind
    h: mb.segH
    fontPx: mb.fontPx
    blockRadius: mb.style.radius === undefined ? 0 : Math.round(mb.style.radius * mb.segH / 34)
    fontFamily: typeof mb.style.fontFamily === "string" && mb.style.fontFamily !== "" ? mb.style.fontFamily : Style.font.family
    gap: mb.gap
    depthFactor: mb.style.depth === undefined ? 0.42 : mb.style.depth
    mode: mb.modeFor(region, idx)
    flatEdge: mb.style.flatEnds !== false && ((region === "left" && idx === 0) || (region === "right" && idx === count - 1))
    glyph: entry.icon ? entry.icon : P.glyphFor(moduleId)
    label: mb.showLabels ? P.shortName(moduleId) : ""
    fill: mb.kind === "none" ? "transparent"
      : P.segmentFill(mb.res, P.segmentBase(mb.res, region, idx, count, moduleId), false)
    textColor: mb.kind === "none" || mb.kind === "underline" ? (mb.res.fg || mb.defaults.foreground) : mb.res.text
    selected: mb.interactive && mb.selectedPart === "module:" + moduleId
    selectColor: Commons.Color.accent
    onClicked: if (mb.interactive) mb.partClicked("module:" + moduleId)
  }

  Item {
    id: canvas
    width: mb.width / mb.fit
    height: mb.barH + 2 * mb.floatPx
    scale: mb.fit
    transformOrigin: Item.TopLeft

    Rectangle {
      id: barBg
      x: mb.floatPx
      y: mb.floatPx
      width: parent.width - 2 * mb.floatPx
      height: mb.barH
      color: mb.floatPx > 0 ? "transparent" : mb.res.bg
      border.width: mb.selectedPart === "bg" ? 2 : 0
      border.color: Commons.Color.accent

      MouseArea {
        anchors.fill: parent
        enabled: mb.interactive
        onClicked: mb.partClicked("bg")
      }
    }

    Row {
      id: leftRow
      x: mb.floatPx + mb.edge
      y: mb.floatPx + Math.round((mb.barH - mb.segH) / 2)
      Repeater {
        model: mb.lane("left")
        MiniSeg { entry: modelData; idx: index; region: "left"; count: mb.lane("left").length }
      }
    }

    Row {
      id: centerRow
      anchors.horizontalCenter: parent.horizontalCenter
      y: mb.floatPx + Math.round((mb.barH - mb.segH) / 2)
      Repeater {
        model: mb.lane("center")
        MiniSeg { entry: modelData; idx: index; region: "center"; count: mb.lane("center").length }
      }
    }

    Row {
      id: rightRow
      anchors.right: parent.right
      anchors.rightMargin: mb.floatPx + mb.edge
      y: mb.floatPx + Math.round((mb.barH - mb.segH) / 2)
      Repeater {
        model: mb.lane("right")
        MiniSeg { entry: modelData; idx: index; region: "right"; count: mb.lane("right").length }
      }
    }
  }
}

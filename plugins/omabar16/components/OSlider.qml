import QtQuick
import qs.Commons
import qs.Commons as Commons

// Labelled slider with a numeric read-out.
Item {
  id: s

  property string label: ""
  property real from: 0
  property real to: 1
  property real step: 0.01
  property real value: 0
  property int decimals: 0
  property string unit: ""
  signal moved(real v)

  implicitHeight: 34
  implicitWidth: 240

  readonly property real ratio: to === from ? 0 : (value - from) / (to - from)

  Text {
    text: s.label.toUpperCase()
    color: Commons.Color.muted
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body - 2
    font.letterSpacing: 1.5
  }
  Text {
    anchors.right: parent.right
    text: s.value.toFixed(s.decimals) + s.unit
    color: Commons.Color.menu.text
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body - 1
  }
  Rectangle {
    id: track
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    height: 4
    color: Util.alpha(Commons.Color.menu.border, 0.45)

    Rectangle { width: track.width * s.ratio; height: parent.height; color: Commons.Color.accent }
    Rectangle {
      x: track.width * s.ratio - width / 2
      y: -4
      width: 12; height: 12
      color: Commons.Color.background
      border.width: 2
      border.color: Commons.Color.accent
    }
    MouseArea {
      anchors.fill: parent
      anchors.topMargin: -10
      anchors.bottomMargin: -10
      preventStealing: true
      function set(m) {
        var r = Math.max(0, Math.min(1, m.x / width))
        var v = s.from + r * (s.to - s.from)
        v = Math.round(v / s.step) * s.step
        v = Math.max(s.from, Math.min(s.to, v))
        if (v !== s.value) s.moved(v)
      }
      onPressed: function(m) { set(m) }
      onPositionChanged: function(m) { if (pressed) set(m) }
    }
  }
}

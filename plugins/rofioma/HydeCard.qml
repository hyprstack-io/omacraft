import QtQuick
import "RofiFx.js" as Fx

// One entry of a ROFIoma popup with HyDE's wlogout hover (style_1.css,
// button:hover): when it becomes the active entry it swells into its
// margins, rounds its corners and grows its icon, over 0.3s on
// cubic-bezier(.55, 0, .28, 1.682), whose overshoot is the bounce. Leaving
// snaps it back, as GTK does with the transition on :hover alone. hoverStyle
// swaps that for another of RofiFx's hovers, and enter holds where the popup's
// entrance has it (from Fx.enter).
Item {
  id: card

  property string glyph: ""
  property string label: ""
  property bool hot: false
  property bool asking: false
  property bool showLabel: true
  // "card" stacks the icon over the name; "list" puts them on one line.
  property string shape: "card"

  property real radius: 12
  property real hotRadius: 20
  // How far it swells past its cell on each side, across and along.
  property real growX: 0
  property real growY: 0
  // The icon at rest, and how much bigger it gets.
  property real glyphSize: 32
  property real glyphGain: 0.35
  property real textSize: 14
  property string fontFamily: "JetBrainsMono Nerd Font"
  property string glyphFamily: "JetBrainsMono Nerd Font"

  property color restColor: "#222222"
  property color hotColor: "#7aa2f7"
  property color textColor: "#eeeeee"
  property color hotTextColor: "#111111"
  property string askText: "Sure?  Enter · Esc"

  property string hoverStyle: "hyde"
  property real beat: 0
  property var enter: ({ opacity: 1, scale: 1, x: 0, y: 0, rotation: 0, flip: 0 })
  readonly property var fx: Fx.hover(hoverStyle, t, beat)

  signal clicked()
  signal entered()

  // 0 at rest, 1 when hot; it passes 1 on the way, which is the bounce.
  property real t: 0
  NumberAnimation {
    id: swell
    target: card; property: "t"; from: 0; to: 1
    duration: 300
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.55, 0.0, 0.28, 1.682, 1, 1]
  }
  onHotChanged: { swell.stop(); if (hot) swell.start(); else t = 0 }
  z: hot ? 2 : 0

  opacity: enter.opacity
  scale: enter.scale * fx.scale
  rotation: enter.rotation + fx.rotation
  transform: [
    Translate { x: card.enter.x; y: card.enter.y + card.fx.y },
    Rotation { origin.x: card.width / 2; origin.y: card.height / 2; axis { x: 0; y: 1; z: 0 } angle: card.enter.flip }
  ]

  // The halo, soft rings of the lit colour fading outwards.
  Repeater {
    model: card.fx.glow > 0 ? [18, 12, 6] : []
    Rectangle {
      required property int modelData
      anchors.fill: parent
      anchors.margins: -modelData
      radius: body.radius + modelData
      color: card.hotColor
      opacity: card.fx.glow * 0.14
    }
  }

  Rectangle {
    id: body
    readonly property real swell: card.t * card.fx.swell
    readonly property bool lit: card.hot && !card.fx.outline
    anchors.fill: parent
    anchors.leftMargin: -card.growX * swell
    anchors.rightMargin: -card.growX * swell
    anchors.topMargin: -card.growY * swell
    anchors.bottomMargin: -card.growY * swell
    radius: Math.max(0, Math.min(Math.min(width, height) / 2, card.radius + (card.hotRadius - card.radius) * swell))
    color: lit ? card.hotColor : card.restColor
    border.width: card.hot && card.fx.outline ? 2 : 0
    border.color: card.hotColor
    antialiasing: true

    Column {
      visible: card.shape === "card"
      anchors.centerIn: parent
      spacing: card.textSize * 0.35
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: card.glyph
        color: body.lit ? card.hotTextColor : card.hot ? card.hotColor : card.textColor
        font.family: card.glyphFamily
        font.pixelSize: Math.max(6, card.glyphSize * (1 + card.glyphGain * body.swell))
      }
      Text {
        visible: card.showLabel && card.label !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, body.width - 12)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: card.asking ? card.askText : card.label
        color: body.lit ? card.hotTextColor : card.hot ? card.hotColor : card.textColor
        font.family: card.fontFamily
        font.pixelSize: card.textSize
        font.bold: card.asking
      }
    }

    Row {
      visible: card.shape === "list"
      anchors.verticalCenter: parent.verticalCenter
      x: 14 + card.growX * body.swell * 0.5
      spacing: 12
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: card.glyph !== ""
        text: card.glyph
        color: body.lit ? card.hotTextColor : card.hot ? card.hotColor : card.textColor
        font.family: card.glyphFamily
        font.pixelSize: Math.max(6, card.glyphSize * (1 + card.glyphGain * body.swell))
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: card.showLabel
        text: card.asking ? card.askText : card.label
        color: body.lit ? card.hotTextColor : card.hot ? card.hotColor : card.textColor
        font.family: card.fontFamily
        font.pixelSize: card.textSize
        font.bold: card.asking
      }
    }
  }

  // The base cell takes the pointer, so a swelling card never steals it
  // from its neighbour.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) card.entered()
    onClicked: card.clicked()
  }
}

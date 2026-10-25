import QtQuick
import qs.Commons
import qs.Commons as Commons

// A clickable tile with a glyph, a title and a short description. Used for
// the overview shortcuts, transitions and animation presets.
Rectangle {
  id: card

  property string glyph: ""
  property string title: ""
  property string description: ""
  property string badge: ""
  property color foreground: Commons.Color.menu.text
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.menuFamily
  property bool highlighted: false
  signal clicked()

  // Tall enough that a two-line description never runs into the glyph.
  implicitHeight: Math.max(Style.space(96),
    glyphText.y + glyphText.implicitHeight + Style.space(6) + textColumn.implicitHeight + Style.space(14))
  radius: Style.cornerRadius > 0 ? Style.space(8) : 0
  color: mouse.containsMouse ? Util.alpha(accent, 0.1) : Util.alpha(foreground, 0.04)
  border.width: 1
  border.color: (mouse.containsMouse || highlighted) ? Util.alpha(accent, 0.7) : Util.alpha(foreground, 0.1)
  Behavior on color { ColorAnimation { duration: Style.duration(120) } }

  Text {
    id: glyphText
    x: Style.space(14)
    y: Style.space(14)
    text: card.glyph
    color: card.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.display
  }

  Text {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    visible: card.badge !== ""
    text: card.badge
    color: Util.alpha(card.foreground, 0.45)
    font.family: card.fontFamily
    font.pixelSize: Style.font.caption
  }

  Column {
    id: textColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.space(14)
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: card.title
      elide: Text.ElideRight
      color: card.foreground
      font.family: card.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Text {
      width: parent.width
      visible: card.description !== ""
      text: card.description
      elide: Text.ElideRight
      maximumLineCount: 2
      wrapMode: Text.Wrap
      color: Util.alpha(card.foreground, 0.6)
      font.family: card.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: card.clicked()
  }
}

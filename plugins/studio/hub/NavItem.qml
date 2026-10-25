import QtQuick
import qs.Commons
import qs.Commons as Commons

// One sidebar entry: glyph, label, an optional hint on the right, and an
// accent bar on the page that is showing.
Rectangle {
  id: item

  property string glyph: ""
  property string label: ""
  property string hint: ""
  property bool current: false
  property color foreground: Commons.Color.menu.text
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.menuFamily
  signal clicked()

  implicitHeight: Style.space(34)
  radius: Style.cornerRadius > 0 ? Style.space(6) : 0
  color: current ? Util.alpha(accent, 0.16) : (mouse.containsMouse ? Util.alpha(foreground, 0.07) : "transparent")

  Rectangle {
    visible: item.current
    width: Style.space(3)
    height: parent.height - Style.space(12)
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    radius: width / 2
    color: item.accent
  }

  Text {
    id: glyphText
    anchors.left: parent.left
    anchors.leftMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(20)
    horizontalAlignment: Text.AlignHCenter
    text: item.glyph
    color: item.current ? item.accent : Util.alpha(item.foreground, 0.7)
    font.family: Style.font.family
    font.pixelSize: Style.font.body + 2
  }

  Text {
    anchors.left: glyphText.right
    anchors.leftMargin: Style.space(10)
    anchors.right: hintText.left
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    text: item.label
    elide: Text.ElideRight
    color: item.current ? item.accent : item.foreground
    font.family: item.fontFamily
    font.pixelSize: Style.font.body
    font.bold: item.current
  }

  Text {
    id: hintText
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    text: item.hint
    color: Util.alpha(item.foreground, 0.4)
    font.family: item.fontFamily
    font.pixelSize: Style.font.caption
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: item.clicked()
  }
}

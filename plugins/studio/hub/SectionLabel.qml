import QtQuick
import qs.Commons
import qs.Commons as Commons

// Small caps heading with a hairline, used to group settings on a page.
Item {
  id: label

  property string text: ""
  property color foreground: Commons.Color.menu.text
  property string fontFamily: Style.font.menuFamily

  width: parent ? parent.width : 0
  implicitHeight: caption.implicitHeight + Style.space(6)

  Text {
    id: caption
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(3)
    text: label.text.toUpperCase()
    color: Util.alpha(label.foreground, 0.5)
    font.family: label.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1.5
  }
  Rectangle {
    anchors.left: caption.right
    anchors.leftMargin: Style.space(10)
    anchors.right: parent.right
    anchors.verticalCenter: caption.verticalCenter
    height: 1
    color: Util.alpha(label.foreground, 0.12)
  }
}

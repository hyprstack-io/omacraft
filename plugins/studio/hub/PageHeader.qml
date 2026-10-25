import QtQuick
import qs.Commons
import qs.Commons as Commons

// Title and one-line explanation at the top of every page, with room on the
// right for the page's own actions.
Item {
  id: header

  property string title: ""
  property string subtitle: ""
  property color foreground: Commons.Color.menu.text
  property string fontFamily: Style.font.menuFamily
  default property alias actions: actionRow.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(texts.implicitHeight, actionRow.implicitHeight)

  Column {
    id: texts
    anchors.left: parent.left
    anchors.right: actionRow.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(3)

    Text {
      text: header.title
      color: header.foreground
      font.family: header.fontFamily
      font.pixelSize: Style.font.title + 2
      font.bold: true
    }
    Text {
      width: parent.width
      visible: header.subtitle !== ""
      text: header.subtitle
      wrapMode: Text.Wrap
      color: Util.alpha(header.foreground, 0.6)
      font.family: header.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  Row {
    id: actionRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)
  }
}

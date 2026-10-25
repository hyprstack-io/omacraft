import QtQuick
import qs.Commons
import qs.Commons as Commons

// A labelled settings line: fixed-width label on the left, controls in a row.
Item {
  id: row

  property string label: ""
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  default property alias content: controls.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(labelText.implicitHeight, controls.implicitHeight)

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(90)
    text: row.label
    color: row.foreground
    opacity: 0.75
    font.family: row.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Row {
    id: controls
    anchors.left: labelText.right
    anchors.leftMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(10)
  }
}

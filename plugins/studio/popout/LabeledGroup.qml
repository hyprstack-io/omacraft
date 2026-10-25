import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A labeled pick-one row for the Studio popout, with an optional line
// explaining the current choice.
Column {
  id: group

  property string label: ""
  property string hint: ""
  property var options: []
  property string value: ""
  property color foreground: Commons.Color.popups.text
  property real labelWidth: Style.space(72)

  signal picked(string value)

  spacing: Style.space(4)

  Row {
    width: parent.width
    spacing: Style.space(8)

    Text {
      width: group.labelWidth
      anchors.verticalCenter: parent.verticalCenter
      text: group.label
      color: Util.alpha(group.foreground, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    ButtonGroup {
      anchors.verticalCenter: parent.verticalCenter
      options: group.options
      value: group.value
      foreground: group.foreground
      fontFamily: Style.font.family
      fontSize: Style.font.caption
      focusable: false
      onChanged: function(v) { group.picked(v) }
    }
  }

  Text {
    visible: group.hint !== ""
    width: parent.width
    leftPadding: group.labelWidth + Style.space(8)
    text: group.hint
    wrapMode: Text.Wrap
    color: Util.alpha(group.foreground, 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}

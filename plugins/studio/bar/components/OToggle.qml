import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
  id: t

  property string label: ""
  property bool checked: false
  signal toggled(bool value)

  implicitHeight: 26
  implicitWidth: lbl.implicitWidth + 52

  Text {
    id: lbl
    anchors.verticalCenter: parent.verticalCenter
    text: t.label.toUpperCase()
    color: Commons.Color.muted
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body - 2
    font.letterSpacing: 1.5
  }
  Rectangle {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 34; height: 16
    color: t.checked ? Util.alpha(Commons.Color.accent, 0.3) : "transparent"
    border.width: 1
    border.color: t.checked ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.7)
    Rectangle {
      x: t.checked ? parent.width - width - 2 : 2
      y: 2
      width: 10; height: 10
      color: t.checked ? Commons.Color.accent : Commons.Color.muted
      Behavior on x { NumberAnimation { duration: 90 } }
    }
  }
  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.checked) }
}

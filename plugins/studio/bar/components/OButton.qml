import QtQuick
import qs.Commons
import qs.Commons as Commons

// Flat, sharp-cornered Omarchy button. `active` marks the current choice.
Rectangle {
  id: b

  property string text: ""
  property string glyph: ""
  property bool active: false
  property bool danger: false
  property bool subtle: false
  property int padX: 12
  signal clicked()

  readonly property color tone: danger ? Commons.Color.urgent : Commons.Color.accent
  implicitWidth: row.implicitWidth + padX * 2
  implicitHeight: 28
  color: active ? Util.alpha(tone, 0.2) : (mouse.containsMouse ? Commons.Color.menu.selectedBackground : "transparent")
  border.width: 1
  border.color: active ? tone : Util.alpha(danger ? Commons.Color.urgent : Commons.Color.menu.border, subtle ? 0.35 : 0.7)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 7
    Text {
      visible: b.glyph !== ""
      text: b.glyph
      color: b.active ? b.tone : Commons.Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body + 1
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: b.text !== ""
      text: b.text
      color: b.active ? b.tone : (b.danger ? Commons.Color.urgent : Commons.Color.menu.text)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: b.clicked()
  }
}

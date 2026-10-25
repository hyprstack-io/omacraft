import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../data/Presets.js" as P

// A draggable module chip. Reports the drag; the page owns the ghost and drop.
Rectangle {
  id: chip

  property string moduleId: ""
  property string lane: ""
  property int laneIndex: -1
  property string name: ""
  property color stripe: Commons.Color.accent
  property bool dimmed: false
  property bool multi: false

  signal dragStarted(real x, real y)
  signal dragMoved(real x, real y)
  signal dragEnded()
  signal removeRequested()

  implicitWidth: row.implicitWidth + 22
  implicitHeight: 32
  color: mouse.containsMouse || mouse.dragging ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.045)
  border.width: 1
  border.color: mouse.containsMouse ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.5)
  opacity: dimmed ? 0.28 : 1

  Rectangle { width: 4; height: parent.height; color: chip.stripe }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    x: 14
    spacing: 8
    Text {
      text: P.glyphFor(chip.moduleId)
      color: chip.stripe
      font.family: Style.font.family
      font.pixelSize: Style.font.title + 1
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: chip.name
      color: Commons.Color.menu.text
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: chip.multi
      text: "×n"
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    // The tray scrolls; without this it would steal the drag from the chip.
    preventStealing: true
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property bool dragging: false
    property real px: 0
    property real py: 0

    onPressed: function(m) { px = m.x; py = m.y; dragging = false }
    onPositionChanged: function(m) {
      if (!(m.buttons & Qt.LeftButton)) return
      if (!dragging && Math.abs(m.x - px) + Math.abs(m.y - py) > 8) {
        dragging = true
        chip.dragStarted(m.x, m.y)
      }
      if (dragging) chip.dragMoved(m.x, m.y)
    }
    onReleased: function(m) {
      if (dragging) { dragging = false; chip.dragEnded() }
    }
    onClicked: function(m) { if (m.button === Qt.RightButton) chip.removeRequested() }
  }
}

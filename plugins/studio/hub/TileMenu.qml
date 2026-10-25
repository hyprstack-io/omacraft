import QtQuick
import qs.Commons
import qs.Commons as Commons

// The right-click menu for wallpaper tiles. One instance lives on top of the
// Studio card; a page opens it with a list of entries:
//
//   { label, glyph, action: function() {}, danger: bool, confirm: "Click again to delete" }
//
// An entry with `confirm` needs a second click, so a stray right-click and
// click cannot delete a file.
Item {
  id: menu

  property color foreground: Commons.Color.menu.text
  property color background: Commons.Color.menu.background
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.menuFamily

  property var entries: []
  property int armed: -1
  readonly property bool shown: entries.length > 0

  visible: shown

  function open(source, x, y, list) {
    var p = source.mapToItem(menu, x, y)
    armed = -1
    entries = list || []
    panel.x = Math.max(Style.space(4), Math.min(p.x, menu.width - panel.width - Style.space(4)))
    panel.y = Math.max(Style.space(4), Math.min(p.y, menu.height - panel.height - Style.space(4)))
  }

  function close() {
    entries = []
    armed = -1
  }

  // Click anywhere else (either button) to dismiss.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: menu.close()
    onWheel: menu.close()
  }

  Shortcut { sequence: "Escape"; enabled: menu.shown; onActivated: menu.close() }

  Rectangle {
    id: panel
    width: Style.space(250)
    height: list.implicitHeight + Style.space(10)
    radius: Style.cornerRadius > 0 ? Style.space(8) : 0
    color: menu.background
    border.width: 1
    border.color: Util.alpha(menu.foreground, 0.18)

    Column {
      id: list
      anchors.fill: parent
      anchors.margins: Style.space(5)

      Repeater {
        model: menu.entries

        Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool isArmed: menu.armed === index
          readonly property color tint: modelData.danger ? Commons.Color.urgent : menu.foreground
          width: list.width
          height: Style.space(32)
          radius: Style.cornerRadius > 0 ? Style.space(5) : 0
          color: isArmed ? Util.alpha(Commons.Color.urgent, 0.22)
            : (rowMouse.containsMouse ? Util.alpha(row.modelData.danger ? Commons.Color.urgent : menu.accent, 0.16) : "transparent")

          Text {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(20)
            text: row.modelData.glyph || ""
            color: row.tint
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall + 2
          }
          Text {
            anchors.left: glyph.right
            anchors.right: parent.right
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: row.isArmed ? (row.modelData.confirm || "Click again") : row.modelData.label
            elide: Text.ElideRight
            color: row.tint
            font.family: menu.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: row.isArmed
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (row.modelData.confirm && !row.isArmed) { menu.armed = row.index; return }
              var action = row.modelData.action
              menu.close()
              if (action) action()
            }
          }
        }
      }
    }
  }
}

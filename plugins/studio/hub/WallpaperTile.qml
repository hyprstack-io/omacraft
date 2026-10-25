import QtQuick
import qs.Commons
import qs.Commons as Commons

// One wallpaper in a results or library grid: thumbnail, a caption and the
// image's own colors on hover, a ring on the current wallpaper, and a pulse
// while it is being applied.
Item {
  id: tile

  property string source: ""
  property bool local: false
  property string caption: ""
  property string tooltip: ""
  property var swatches: []
  property bool busy: false
  property bool current: false
  // A heart in the corner: always shown when set, on hover otherwise.
  property bool favorite: false
  property bool canFavorite: true
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  signal activated()
  // Right-click, with where in the tile it happened (for the context menu).
  signal secondary(real x, real y)
  signal favoriteToggled()

  readonly property real radius: Style.cornerRadius > 0 ? Style.space(6) : 0

  Rectangle {
    id: frame
    anchors.fill: parent
    radius: tile.radius
    color: Qt.rgba(tile.foreground.r, tile.foreground.g, tile.foreground.b, 0.06)
    clip: true

    Image {
      id: thumb
      anchors.fill: parent
      source: tile.source ? Util.fileUrl(tile.source) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      // Library tiles point at full-size files; decode them small.
      sourceSize.width: tile.local ? 360 : 0
      cache: true
      smooth: true
      opacity: status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }
    }

    Text {
      anchors.centerIn: parent
      visible: thumb.status !== Image.Ready
      text: thumb.status === Image.Error || !tile.source ? "no preview" : "…"
      color: Qt.darker(tile.foreground, 1.6)
      font.family: tile.fontFamily
      font.pixelSize: Style.font.caption
    }

    // Hover caption bar
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: captionText.implicitHeight + Style.space(8)
      color: Qt.rgba(0, 0, 0, 0.6)
      visible: mouse.containsMouse
      Text {
        id: captionText
        anchors.left: parent.left
        anchors.right: swatchRow.left
        anchors.leftMargin: Style.space(6)
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        text: tile.caption
        elide: Text.ElideMiddle
        color: "white"
        font.family: tile.fontFamily
        font.pixelSize: Style.font.caption
      }
      Row {
        id: swatchRow
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
          model: tile.swatches.slice(0, 5)
          Rectangle {
            required property string modelData
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            color: modelData
          }
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.45)
      visible: tile.busy
      Text {
        anchors.centerIn: parent
        text: "Applying…"
        color: "white"
        font.family: tile.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        SequentialAnimation on opacity {
          running: tile.busy
          loops: Animation.Infinite
          NumberAnimation { to: 0.3; duration: 450 }
          NumberAnimation { to: 1; duration: 450 }
        }
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: tile.radius
    color: "transparent"
    border.width: tile.current ? Style.space(3) : (mouse.containsMouse ? 1 : 0)
    border.color: tile.current ? Commons.Color.accent : Qt.rgba(tile.foreground.r, tile.foreground.g, tile.foreground.b, 0.5)
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(event) {
      if (event.button === Qt.RightButton) tile.secondary(event.x, event.y)
      else tile.activated()
    }
  }

  Rectangle {
    id: heart
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.space(6)
    width: Style.space(28)
    height: width
    radius: width / 2
    visible: tile.canFavorite && (tile.favorite || mouse.containsMouse || heartMouse.containsMouse)
    color: Qt.rgba(0, 0, 0, heartMouse.containsMouse ? 0.75 : 0.5)

    Text {
      anchors.centerIn: parent
      text: tile.favorite ? "♥" : "♡"
      color: tile.favorite ? "#ff5c8a" : "white"
      font.pixelSize: Style.font.bodySmall + 3
    }

    MouseArea {
      id: heartMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.favoriteToggled()
    }
  }
}

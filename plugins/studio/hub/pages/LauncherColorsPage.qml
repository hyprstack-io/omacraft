import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../LauncherStyles.js" as Styles
import ".."

// The launcher's color scheme, each shown on the current layout.
Flickable {
  id: page

  property var hub
  property var store
  property var launcher

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  ColumnLayout {
    id: column
    width: page.width
    spacing: Style.space(14)

    PageHeader {
      Layout.fillWidth: true
      title: "Launcher colors"
      subtitle: "“Omarchy theme” follows your desktop colors, including wallpaper colors. The others are fixed rofi-style schemes. Inside the launcher, Ctrl+T cycles them."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

      Button {
        text: "Try it"
        iconText: ""
        tooltipText: "Open the launcher to see the colors"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        active: true
        onClicked: page.hub.previewLauncherRequested()
      }
    }

    GridLayout {
      Layout.fillWidth: true
      columns: Math.max(2, Math.floor(page.width / Style.space(200)))
      columnSpacing: Style.space(12)
      rowSpacing: Style.space(12)

      Repeater {
        model: Styles.schemes

        Rectangle {
          id: card
          required property var modelData
          readonly property bool current: page.launcher.schemeId === modelData.id
          readonly property var colors: page.hub.schemeColors(modelData.id)
          Layout.fillWidth: true
          implicitHeight: preview.height + Style.space(66)
          radius: Style.cornerRadius > 0 ? Style.space(8) : 0
          color: mouse.containsMouse ? Util.alpha(page.hub.accent, 0.08) : Util.alpha(page.hub.fg, 0.04)
          border.width: card.current ? 2 : 1
          border.color: card.current ? page.hub.accent : (mouse.containsMouse ? Util.alpha(page.hub.accent, 0.6) : Util.alpha(page.hub.fg, 0.1))

          LayoutPreview {
            id: preview
            x: Style.space(10)
            y: Style.space(10)
            width: parent.width - Style.space(20)
            height: width * 9 / 16
            layoutId: page.launcher.layoutId
            scheme: card.colors
          }

          Row {
            id: swatchRow
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.top: preview.bottom
            anchors.topMargin: Style.space(8)
            spacing: 0
            Repeater {
              model: ["bg", "alt", "fg", "sel", "active", "urgent"]
              Rectangle {
                required property string modelData
                width: (card.width - Style.space(20)) / 6
                height: Style.space(8)
                color: card.colors[modelData] || "transparent"
              }
            }
          }

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: swatchRow.bottom
            anchors.margins: Style.space(10)
            anchors.topMargin: Style.space(8)
            text: card.modelData.name + (card.current ? "   ✓" : "")
            elide: Text.ElideRight
            color: card.current ? page.hub.accent : page.hub.fg
            font.family: page.hub.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.launcher.setStyle(page.launcher.layoutId, card.modelData.id)
            onDoubleClicked: {
              page.launcher.setStyle(page.launcher.layoutId, card.modelData.id)
              page.hub.previewLauncherRequested()
            }
          }
        }
      }
    }
  }
}

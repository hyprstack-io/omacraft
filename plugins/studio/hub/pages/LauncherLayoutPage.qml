import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../LauncherStyles.js" as Styles
import ".."

// The launcher's layout, drawn in the current color scheme.
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
      title: "Launcher layout"
      subtitle: "Where and how the Omarchy menu and app launcher appear. Inside the launcher, Ctrl+L cycles layouts (Shift+Ctrl+L goes back)."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

      Button {
        text: "Surprise me"
        iconText: String.fromCodePoint(0xF049D)
        tooltipText: "A random layout and color scheme"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        onClicked: page.launcher.setStyle(
          Styles.layouts[Math.floor(Math.random() * Styles.layouts.length)].id,
          Styles.schemes[Math.floor(Math.random() * Styles.schemes.length)].id)
      }
      Button {
        text: "Try it"
        iconText: ""
        tooltipText: "Open the launcher to see the layout"
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
      columns: Math.max(2, Math.floor(page.width / Style.space(230)))
      columnSpacing: Style.space(12)
      rowSpacing: Style.space(12)

      Repeater {
        model: Styles.layouts

        Rectangle {
          id: card
          required property var modelData
          readonly property bool current: page.launcher.layoutId === modelData.id
          Layout.fillWidth: true
          implicitHeight: preview.height + texts.implicitHeight + Style.space(28)
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
            layoutId: card.modelData.id
            scheme: page.hub.schemeColors(page.launcher.schemeId)
          }

          Column {
            id: texts
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: preview.bottom
            anchors.margins: Style.space(10)
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: card.modelData.icon + "  " + card.modelData.name + (card.current ? "   ✓" : "")
              color: card.current ? page.hub.accent : page.hub.fg
              font.family: page.hub.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              width: parent.width
              text: card.modelData.description
              wrapMode: Text.Wrap
              color: page.hub.dim
              font.family: page.hub.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.launcher.setStyle(card.modelData.id, page.launcher.schemeId)
            onDoubleClicked: {
              page.launcher.setStyle(card.modelData.id, page.launcher.schemeId)
              page.hub.previewLauncherRequested()
            }
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      text: "Double-click a layout to open the launcher in it. From a terminal: omarchy-launcher-style layout <name>."
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}

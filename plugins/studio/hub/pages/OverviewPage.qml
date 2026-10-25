import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".."

// Landing page: what the desktop looks like right now, the actions people
// reach for most, and a way into every other page.
Flickable {
  id: page

  property var hub
  property var store
  property var launcher

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  readonly property string wallpaperPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  property string wallpaperSource: ""

  // The background is a symlink that changes target in place; drop the source
  // first so the uncached Image re-reads it.
  function reloadWallpaper() {
    wallpaperSource = ""
    Qt.callLater(function() { page.wallpaperSource = Util.fileUrl(page.wallpaperPath) })
  }
  Component.onCompleted: reloadWallpaper()
  Connections {
    target: page.store
    function onStatusChanged() { page.reloadWallpaper() }
  }

  ColumnLayout {
    id: column
    width: page.width
    spacing: Style.space(16)

    PageHeader {
      Layout.fillWidth: true
      title: "Overview"
      subtitle: "Your wallpaper, colors and launcher at a glance. Pick a page on the left to change any of them."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
    }

    // ---------------------------------------------------------- hero
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(16)

      Rectangle {
        Layout.preferredWidth: Math.min(page.width * 0.5, Style.space(460))
        Layout.preferredHeight: Layout.preferredWidth * 9 / 16
        radius: Style.cornerRadius > 0 ? Style.space(8) : 0
        color: Util.alpha(page.hub.fg, 0.06)
        clip: true
        border.width: 1
        border.color: Util.alpha(page.hub.fg, 0.12)

        Image {
          anchors.fill: parent
          anchors.margins: 1
          source: page.wallpaperSource
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          sourceSize.width: 920
        }

        Rectangle {
          anchors.fill: parent
          color: Util.alpha("#000000", 0.35)
          visible: page.store.applying
          Text {
            anchors.centerIn: parent
            text: "Applying…"
            color: "#ffffff"
            font.family: page.hub.fontFamily
            font.pixelSize: Style.font.title
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(10)

        Text {
          Layout.fillWidth: true
          text: page.store.basename(page.store.status.current) || "No wallpaper yet"
          elide: Text.ElideMiddle
          color: page.hub.fg
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
        Text {
          Layout.fillWidth: true
          text: page.store.status.themeIsDynamic ? "Desktop colors come from this wallpaper"
            : (page.store.status.theme ? "Omarchy theme: " + page.store.status.theme : "")
          color: page.hub.dim
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // Palette
        Row {
          spacing: Style.space(4)
          visible: page.store.colors.background !== undefined
          Repeater {
            model: page.store.swatchKeys
            Rectangle {
              required property string modelData
              width: Style.space(22)
              height: Style.space(30)
              radius: Style.cornerRadius > 0 ? Style.space(4) : 0
              color: page.store.colors[modelData] || "transparent"
              border.width: 1
              border.color: Util.alpha(page.hub.fg, 0.2)
            }
          }
        }

        Flow {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Button {
            text: "Next wallpaper"
            iconText: String.fromCodePoint(0xF0F27)
            tooltipText: "A random wallpaper from the auto-change source"
            bordered: true
            fontSize: Style.font.bodySmall
            foreground: page.hub.fg
            fontFamily: page.hub.fontFamily
            iconSpinning: page.store.applying && page.store.busyTarget === "next"
            onClicked: page.store.runAction(["next"])
          }
          Button {
            text: "Recolor from wallpaper"
            iconText: String.fromCodePoint(0xF03D8)
            tooltipText: "Build and apply an Omarchy theme from the current wallpaper"
            bordered: true
            fontSize: Style.font.bodySmall
            foreground: page.hub.fg
            fontFamily: page.hub.fontFamily
            iconSpinning: page.store.applying && page.store.busyTarget === "theme"
            onClicked: page.store.runAction(["theme"])
          }
          Button {
            text: "Try the launcher"
            iconText: ""
            tooltipText: "Open the launcher in its current style"
            bordered: true
            fontSize: Style.font.bodySmall
            foreground: page.hub.fg
            fontFamily: page.hub.fontFamily
            onClicked: page.hub.previewLauncherRequested()
          }
        }

        // Status lines
        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: Style.space(12)
          rowSpacing: Style.space(4)

          Repeater {
            model: [
              { k: "Auto-change", v: page.store.countdownText(), p: "autochange" },
              { k: "Transition", v: (page.store.transition.type || "grow") + " · " + (Number(page.store.transition.duration) || 900) + " ms · " + (page.store.cfg.fill || "crop"), p: "transitions" },
              { k: "Color mode", v: (page.store.paletteSettings.mode || "auto") + " · " + (page.store.paletteSettings.style || "balanced"), p: "colors" },
              { k: "Launcher", v: page.launcher.layoutDef.name + " · " + page.launcher.schemeDef.name, p: "launcher-layout" }
            ]
            delegate: Item {
              required property var modelData
              Layout.fillWidth: true
              Layout.columnSpan: 2
              implicitHeight: Math.max(kText.implicitHeight, vText.implicitHeight) + Style.space(4)
              Text {
                id: kText
                width: Style.space(100)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.k
                color: page.hub.dim
                font.family: page.hub.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                id: vText
                anchors.left: kText.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.v + "   ›"
                elide: Text.ElideRight
                color: linkMouse.containsMouse ? page.hub.accent : page.hub.fg
                font.family: page.hub.fontFamily
                font.pixelSize: Style.font.bodySmall
                MouseArea {
                  id: linkMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: page.hub.go(modelData.p)
                }
              }
            }
          }
        }
      }
    }

    // ---------------------------------------------------------- jump grid
    SectionLabel { Layout.fillWidth: true; text: "Everything in Studio"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    GridLayout {
      Layout.fillWidth: true
      columns: Math.max(2, Math.floor(page.width / Style.space(210)))
      columnSpacing: Style.space(10)
      rowSpacing: Style.space(10)

      Repeater {
        model: page.hub.pages.filter(function(p) { return p.id !== "overview" })
        ActionCard {
          required property var modelData
          Layout.fillWidth: true
          glyph: modelData.glyph
          title: modelData.label
          description: modelData.description
          badge: modelData.group
          foreground: page.hub.fg
          accent: page.hub.accent
          fontFamily: page.hub.fontFamily
          onClicked: page.hub.go(modelData.id)
        }
      }
    }
  }
}

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."

// Timed wallpaper rotation. The timer lives in this plugin's background
// service, survives shell restarts, and skips recently used wallpapers.
Flickable {
  id: page

  property var hub
  property var store
  property var launcher

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  Column {
    id: column
    width: page.width
    spacing: Style.space(14)

    PageHeader {
      title: "Auto-change"
      subtitle: "Swap the wallpaper on a timer. Recently used wallpapers are skipped, and if Wallhaven is unreachable it retries in five minutes."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

      Button {
        text: "Change now"
        iconText: String.fromCodePoint(0xF0F27)
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        iconSpinning: page.store.applying && page.store.busyTarget === "next"
        onClicked: page.store.runAction(["next"])
      }
    }

    // Countdown banner
    Rectangle {
      width: parent.width
      height: Style.space(64)
      radius: Style.cornerRadius > 0 ? Style.space(8) : 0
      color: Util.alpha(page.hub.accent, (Number(page.store.rotationCfg.interval) || 0) > 0 ? 0.12 : 0.04)
      border.width: 1
      border.color: Util.alpha(page.hub.accent, 0.35)

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(14)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "⏱"
          color: page.hub.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: page.store.countdownText()
            color: page.hub.fg
            font.family: page.hub.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            text: "Source: " + ({ search: "your last Wallhaven search", local: "your local folders", library: "your library", favorites: "your favorites" })[page.store.rotationCfg.source || "search"]
            color: page.hub.dim
            font.family: page.hub.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }

    SectionLabel { text: "Schedule"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    SettingRow {
      label: "Every"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      ButtonGroup {
        options: [
          { value: "0", label: "Off" }, { value: "5", label: "5m" }, { value: "15", label: "15m" },
          { value: "30", label: "30m" }, { value: "60", label: "1h" }, { value: "180", label: "3h" },
          { value: "360", label: "6h" }, { value: "1440", label: "24h" }
        ]
        value: String(Number(page.store.rotationCfg.interval) || 0)
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setOption("rotation.interval", Number(v)) }
      }
    }

    SettingRow {
      label: "From"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      ButtonGroup {
        options: [
          { value: "search", label: "Last search (random)" },
          { value: "local", label: "Local folders" },
          { value: "library", label: "Library" },
          { value: "favorites", label: "Favorites" }
        ]
        value: page.store.rotationCfg.source || "search"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setOption("rotation.source", v) }
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.Wrap
      text: "Tip: with “Theme the desktop from the wallpaper” on (Colors page), every change also recolors the desktop."
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}

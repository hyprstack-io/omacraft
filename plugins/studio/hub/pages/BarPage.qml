import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."
import "../../bar/components"

// One of the omabar16 customizer tabs inside Studio: a header with
// undo/redo/revert, a note about which bar is active, the live preview, and
// the omabar16 page itself (Modules, Layout, Themes or Studio).
ColumnLayout {
  id: page

  property var hub
  property var store
  property var launcher
  property var ctl
  property string kind: "modules"

  readonly property var info: ({
    modules: { title: "Bar modules", subtitle: "Drag widgets between the left, center and right lanes, in from Available, or onto Available to remove them. Right-click a chip to remove it." },
    layout: { title: "Bar layout", subtitle: "Screen edge, float, padding and transparency, plus over a hundred preset arrangements (Studio, JaKooLit, HANCORE), some of which also move the bar. Presets move widgets but keep their settings." },
    themes: { title: "Bar themes", subtitle: "Preset looks, JaKooLit and HANCORE styles and base16 schemes, plus your own saved, imported and exported themes." },
    studio: { title: "Bar studio", subtitle: "Click any part of the preview to color it with the hex picker; tune shape, fill, gap, depth, size and font; save the result as a theme." }
  })[kind]

  readonly property bool onOmabar: ctl.activeBarId === "omabar16"
  readonly property string sessionBarName: ctl.sessionBarId === "" || ctl.sessionBarId === "omarchy.bar" ? "the stock Omarchy bar" : ctl.sessionBarId

  spacing: Style.space(10)

  PageHeader {
    Layout.fillWidth: true
    title: page.info.title
    subtitle: page.info.subtitle
    foreground: page.hub.fg
    fontFamily: page.hub.fontFamily

    Button {
      text: "Undo"
      tooltipText: "Ctrl+Z"
      enabled: page.ctl.canUndo
      opacity: enabled ? 1 : 0.4
      fontSize: Style.font.caption
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      onClicked: page.ctl.undo()
    }
    Button {
      text: "Redo"
      tooltipText: "Ctrl+Shift+Z"
      enabled: page.ctl.canRedo
      opacity: enabled ? 1 : 0.4
      fontSize: Style.font.caption
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      onClicked: page.ctl.redo()
    }
    Button {
      text: "Revert"
      tooltipText: "Back to how the bar looked when you opened these pages"
      fontSize: Style.font.caption
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      onClicked: page.ctl.revert()
    }
    Button {
      text: "Reset"
      tooltipText: "omabar16's default layout and look"
      fontSize: Style.font.caption
      foreground: Commons.Color.urgent
      fontFamily: page.hub.fontFamily
      bordered: true
      onClicked: page.ctl.resetDefaults()
    }
  }

  // Which bar these edits show up on.
  Rectangle {
    Layout.fillWidth: true
    visible: page.ctl.loaded && (!page.onOmabar || page.ctl.sessionBarId !== "omabar16")
    implicitHeight: bannerRow.implicitHeight + Style.space(16)
    radius: Style.cornerRadius > 0 ? Style.space(8) : 0
    color: Util.alpha(page.hub.accent, 0.1)
    border.width: 1
    border.color: Util.alpha(page.hub.accent, 0.4)

    RowLayout {
      id: bannerRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(12)
      spacing: Style.space(10)

      Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: page.onOmabar
          ? "You're on the omabar16 bar now. You were using " + page.sessionBarName + " when you opened these pages."
          : "These pages edit the omabar16 bar. You're using " + page.sessionBarName + ", so your first change switches the bar to omabar16 (layout and widget settings carry over)."
        color: page.hub.fg
        font.family: page.hub.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Button {
        text: page.onOmabar ? "Switch back" : "Switch to omabar16 now"
        tooltipText: page.onOmabar ? "Make " + page.sessionBarName + " the active bar again (your edits stay saved)" : "Make omabar16 the active bar without changing anything else"
        fontSize: Style.font.caption
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        onClicked: page.ctl.useBar(page.onOmabar ? page.ctl.sessionBarId : "omabar16")
      }
    }
  }

  // Live preview
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: preview.implicitHeight + Style.space(34)
    radius: Style.cornerRadius > 0 ? Style.space(8) : 0
    color: Util.alpha(page.hub.fg, 0.03)
    border.width: 1
    border.color: Util.alpha(page.hub.fg, 0.1)

    Text {
      x: Style.space(10); y: Style.space(6)
      text: "PREVIEW  ·  " + String(page.ctl.cfg.position || "top").toUpperCase()
        + (page.kind === "studio" ? "  ·  click a part to edit it" : "")
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1.5
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      y: Style.space(6)
      text: page.ctl.loaded ? page.ctl.status : "Reading the bar config…"
      color: page.ctl.status === "Applied" || page.ctl.status === "Ready" ? page.hub.dim : page.hub.accent
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }
    MiniBar {
      id: preview
      x: Style.space(10); y: Style.space(24)
      width: parent.width - Style.space(20)
      cfg: page.ctl.cfg
      themeColors: page.ctl.themeColors
      defaults: page.ctl.defaults
      interactive: page.kind === "studio"
      selectedPart: page.ctl.selectedPart
      showLabels: false
      segH: 24
      fontPx: 13
      onPartClicked: function(part) { page.ctl.selectedPart = part }
    }
  }

  // The omabar16 page itself.
  Loader {
    Layout.fillWidth: true
    Layout.fillHeight: true
    sourceComponent: ({ modules: modulesPage, layout: layoutPage, themes: themesPage, studio: studioPage })[page.kind]
  }

  Component { id: modulesPage; ModulesPage { ctl: page.ctl } }
  Component { id: layoutPage; LayoutPage { ctl: page.ctl } }
  Component { id: themesPage; ThemesPage { ctl: page.ctl } }
  Component { id: studioPage; StudioPage { ctl: page.ctl } }
}

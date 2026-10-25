import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."

// Which parts of the interface take the wallpaper's colors. A part that is
// switched off keeps a regular theme's look inside the wallpaper theme
// (bin/hyprskin copies that theme's file in, so Omarchy skips the template).
Flickable {
  id: page

  property var hub
  property var store
  property var launcher

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  readonly property string keepSource: page.store.targetInfo.keepSource || ""
  readonly property int followCount: page.store.targets.filter(function(t) { return t.follow }).length

  function themeLabel(slug) {
    return String(slug || "").split("-").map(function(w) {
      return w.charAt(0).toUpperCase() + w.slice(1)
    }).join(" ")
  }

  readonly property var themeOptions: [{
    value: "",
    label: "Last regular theme" + (page.store.cfg.keepTheme ? "" : (page.keepSource ? " (" + page.themeLabel(page.keepSource) + ")" : ""))
  }].concat(page.store.themeSlugs.map(function(slug) { return { value: slug, label: page.themeLabel(slug) } }))

  // Writes every part at once; one retheme at the end.
  function setAll(follow) {
    var targets = page.store.targets
    for (var i = 0; i < targets.length; i++) {
      if (targets[i].follow === follow) continue
      page.store.setTargetOption("targets." + targets[i].id, follow)
    }
  }

  ColumnLayout {
    id: column
    width: page.width
    spacing: Style.space(14)

    PageHeader {
      Layout.fillWidth: true
      title: "Apply to"
      subtitle: "Choose which parts of the desktop take the wallpaper's colors. Parts you switch off keep a regular theme's look, so you can mix: wallpaper-colored bar and borders, a terminal that stays Tokyo Night."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

      Button {
        text: "All"
        tooltipText: "Every part follows the wallpaper"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        onClicked: page.setAll(true)
      }
      Button {
        text: "None"
        tooltipText: "Every part keeps the regular theme; only the wallpaper changes"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        onClicked: page.setAll(false)
      }
      Button {
        text: "Recolor now"
        iconText: String.fromCodePoint(0xF03D8)
        tooltipText: "Build and apply a theme from the current wallpaper"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        active: true
        iconSpinning: page.store.applying && page.store.busyTarget === "theme"
        onClicked: page.store.runAction(["theme"])
      }
    }

    // Wallpaper colors are off entirely: say so, since nothing here applies.
    Rectangle {
      Layout.fillWidth: true
      visible: page.store.cfg.dynamicColors === false
      implicitHeight: offText.implicitHeight + Style.space(20)
      radius: Style.cornerRadius > 0 ? Style.space(8) : 0
      color: Util.alpha(Commons.Color.urgent, 0.12)
      Text {
        id: offText
        anchors.fill: parent
        anchors.margins: Style.space(10)
        wrapMode: Text.Wrap
        text: "Wallpaper colors are off, so new wallpapers don't change any of these. Turn them on in Look › Colors, or press Recolor now to theme from the current wallpaper once."
        color: page.hub.fg
        font.family: page.hub.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    SectionLabel {
      Layout.fillWidth: true
      text: "Interface parts  ·  " + page.followCount + " of " + page.store.targets.length + " follow the wallpaper"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
    }

    Repeater {
      model: page.store.targets
      Toggle {
        required property var modelData
        Layout.fillWidth: true
        label: modelData.label
        description: modelData.follow
          ? modelData.description
          : modelData.description + "  ·  keeps " + (page.keepSource ? page.themeLabel(page.keepSource) : "its current look") + "'s colors"
        checked: modelData.follow
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        titleSize: Style.font.bodySmall
        onClicked: page.store.setTargetOption("targets." + modelData.id, !modelData.follow)
      }
    }

    SectionLabel { Layout.fillWidth: true; text: "Kept parts look like"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    SettingRow {
      Layout.fillWidth: true
      label: "Theme"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      SearchableDropdown {
        width: Style.space(300)
        showLabel: false
        placeholderText: "Search themes..."
        options: page.themeOptions
        value: page.store.cfg.keepTheme || ""
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        onChanged: function(v) { page.store.setTargetOption("keepTheme", v) }
      }
    }

    Text {
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      text: page.keepSource
        ? "“Last regular theme” is the theme you used before switching to wallpaper colors. Changing it re-themes straight away."
        : "No regular theme is known yet. Pick one here, or set any theme with omarchy theme set and come back. Until then, parts you switch off follow the wallpaper."
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }

    SectionLabel { Layout.fillWidth: true; text: "Studio's own parts"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    Toggle {
      Layout.fillWidth: true
      label: "Launcher"
      description: page.launcher && page.launcher.schemeId === "omarchy"
        ? "Uses the Omarchy theme scheme, so it follows the wallpaper. Switch off to pick a fixed scheme."
        : "Uses a fixed color scheme. Switch on to follow the wallpaper again."
      checked: !!page.launcher && page.launcher.schemeId === "omarchy"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      titleSize: Style.font.bodySmall
      onClicked: {
        if (!page.launcher) return
        if (page.launcher.schemeId === "omarchy") page.hub.go("launcher-colors")
        else page.launcher.setStyle(page.launcher.layoutId, "omarchy")
      }
    }

    Toggle {
      Layout.fillWidth: true
      visible: page.store.status.barId === "omabar16" || page.store.status.barId === "hyprbar16"
      label: "Bar's fixed colors"
      description: "Recolors " + page.store.status.barId + "'s own preset, base16 or Studio colors with the wallpaper's matching ones. The bar's shell colors are under Shell surfaces above."
      checked: page.store.cfg.colorizeBar !== false
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      titleSize: Style.font.bodySmall
      onClicked: page.store.setOption("colorizeBar", !(page.store.cfg.colorizeBar !== false))
    }
  }
}

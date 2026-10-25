import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."

// pywal/wallbash-style theming: build an Omarchy theme from the wallpaper.
Flickable {
  id: page

  property var hub
  property var store
  property var launcher

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  readonly property var schemeOptions: [
    { value: "material", label: "Material", tooltip: "Material You roles from tonal palettes of the wallpaper's key color" },
    { value: "matugen", label: "Matugen", tooltip: "matugen's tonal-spot scheme; runs matugen itself when it is installed" },
    { value: "wallbash", label: "Wallbash", tooltip: "The wallpaper's own main colors carry through to surfaces and accents, like wallbash" },
    { value: "pywal", label: "Pywal", tooltip: "Terminal colors taken almost straight from the image; runs wal itself when it is installed" },
    { value: "flavours", label: "Flavours", tooltip: "A base16 scheme from the image; runs flavours itself when it is installed" },
    { value: "classic", label: "Classic", tooltip: "The original Studio palette" }
  ]

  readonly property var contrastOptions: [
    { value: "soft", label: "Soft", tooltip: "Text at 3:1 or more; the bar may sit close to the wallpaper" },
    { value: "normal", label: "Normal", tooltip: "Text at 4.5:1 or more (WCAG AA); the bar stands clear of the wallpaper" },
    { value: "high", label: "High", tooltip: "Text at 7:1 or more (WCAG AAA); the strongest separation" }
  ]

  // Material roles shown under the theme palette.
  readonly property var roleKeys: [
    "primary", "on_primary", "primary_container", "on_primary_container",
    "secondary", "secondary_container", "tertiary", "tertiary_container",
    "surface", "surface_container", "surface_container_high", "on_surface", "outline", "error"
  ]

  readonly property var modeOptions: [
    { value: "dark", label: "Dark", icon: String.fromCodePoint(0xF0594), tooltip: "Always build a dark theme" },
    { value: "light", label: "Light", icon: String.fromCodePoint(0xF05A8), tooltip: "Always build a light theme" },
    { value: "auto", label: "Auto", icon: String.fromCodePoint(0xF050E), tooltip: "Dark or light depending on the wallpaper's brightness" }
  ]

  ColumnLayout {
    id: column
    width: page.width
    spacing: Style.space(14)

    PageHeader {
      Layout.fillWidth: true
      title: "Colors"
      subtitle: "Theme the whole desktop from the wallpaper: bar, panels, notifications, borders, terminals, btop, Neovim, browser and more."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

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

    // Current palette, large, with role names.
    Flow {
      Layout.fillWidth: true
      spacing: Style.space(6)
      visible: page.store.colors.background !== undefined

      Repeater {
        model: page.store.swatchKeys
        Column {
          required property string modelData
          spacing: Style.space(4)
          Rectangle {
            width: Style.space(62)
            height: Style.space(44)
            radius: Style.cornerRadius > 0 ? Style.space(6) : 0
            color: page.store.colors[modelData] || "transparent"
            border.width: 1
            border.color: Util.alpha(page.hub.fg, 0.2)
          }
          Text {
            width: Style.space(62)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: modelData.replace("lighter_background", "surface").replace("background", "bg").replace("foreground", "fg")
            color: page.hub.dim
            font.family: page.hub.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            width: Style.space(62)
            horizontalAlignment: Text.AlignHCenter
            text: String(page.store.colors[modelData] || "")
            color: Util.alpha(page.hub.fg, 0.45)
            font.family: page.hub.fontFamily
            font.pixelSize: Style.font.caption - 1
          }
        }
      }
    }

    // Material roles, as matugen names them; also exported for templates.
    Flow {
      Layout.fillWidth: true
      spacing: Style.space(4)
      visible: page.store.colors.ui !== undefined

      Repeater {
        model: page.roleKeys
        Rectangle {
          id: roleSwatch
          required property string modelData
          readonly property color fill: (page.store.colors.ui || {})[modelData] || "transparent"
          width: Style.space(92)
          height: Style.space(30)
          radius: Style.cornerRadius > 0 ? Style.space(5) : 0
          color: fill
          border.width: 1
          border.color: Util.alpha(page.hub.fg, 0.15)
          Text {
            anchors.fill: parent
            anchors.margins: Style.space(4)
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: roleSwatch.modelData.replace(/_/g, " ")
            // Black or white, whichever reads on the swatch.
            color: (0.2126 * roleSwatch.fill.r + 0.7152 * roleSwatch.fill.g + 0.0722 * roleSwatch.fill.b) > 0.5 ? "#000000" : "#ffffff"
            font.family: page.hub.fontFamily
            font.pixelSize: Style.font.caption - 1
          }
        }
      }
    }

    SectionLabel { Layout.fillWidth: true; text: "Wallpaper colors"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    Toggle {
      Layout.fillWidth: true
      label: "Theme the desktop from the wallpaper"
      description: "Every wallpaper you apply builds an Omarchy theme (“hyprskin”) from its colors. Right-click a wallpaper to skip this once."
      checked: page.store.cfg.dynamicColors !== false
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      titleSize: Style.font.bodySmall
      onClicked: page.store.setOption("dynamicColors", !(page.store.cfg.dynamicColors !== false))
    }

    Toggle {
      Layout.fillWidth: true
      visible: page.store.status.barId === "omabar16" || page.store.status.barId === "hyprbar16"
      label: "Recolor " + page.store.status.barId + " too"
      description: "Swaps the bar's own fixed colors (preset, base16 or Studio colors) for the wallpaper's matching ones at the same lightness, then keeps the bar text readable and the bar clear of the wallpaper behind it (see Contrast). Your original style comes back when you turn this off or switch to a regular theme."
      checked: page.store.cfg.colorizeBar !== false
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      titleSize: Style.font.bodySmall
      onClicked: page.store.setOption("colorizeBar", !(page.store.cfg.colorizeBar !== false))
    }

    SectionLabel { Layout.fillWidth: true; text: "Palette"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    SettingRow {
      Layout.fillWidth: true
      label: "Mode"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      ButtonGroup {
        options: page.modeOptions
        value: page.store.paletteSettings.mode || "auto"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setPaletteOption("palette.mode", v) }
      }
    }

    SettingRow {
      Layout.fillWidth: true
      label: "Style"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      ButtonGroup {
        options: ["balanced", "vibrant", "pastel", "muted", "mono"]
        value: page.store.paletteSettings.style || "balanced"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setPaletteOption("palette.style", v) }
      }
    }

    SettingRow {
      Layout.fillWidth: true
      label: "Scheme"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      ButtonGroup {
        options: page.schemeOptions
        value: page.store.paletteSettings.scheme || "material"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setPaletteOption("palette.scheme", v) }
      }
    }

    SettingRow {
      Layout.fillWidth: true
      label: "Contrast"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      ButtonGroup {
        options: page.contrastOptions
        value: page.store.paletteSettings.contrast || "normal"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setPaletteOption("palette.contrast", v) }
      }
    }

    // The accent drives borders, selections and highlights everywhere.
    SettingRow {
      Layout.fillWidth: true
      label: "Accent"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: "Auto"
        tooltipText: "The color that stands out most in the wallpaper"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        active: (page.store.paletteSettings.accent || "auto") === "auto"
        onClicked: page.store.setPaletteOption("palette.accent", "auto")
      }

      Repeater {
        model: ["red", "orange", "yellow", "green", "cyan", "blue", "magenta"]
        Rectangle {
          id: accentSwatch
          required property string modelData
          readonly property bool chosen: page.store.paletteSettings.accent === modelData
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(26)
          height: Style.space(26)
          radius: width / 2
          color: page.store.colors[modelData] || "transparent"
          border.width: chosen ? Math.max(2, Style.space(3)) : 1
          border.color: chosen ? page.hub.fg : Util.alpha(page.hub.fg, 0.25)
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.store.setPaletteOption("palette.accent", accentSwatch.modelData)
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      text: "Every recolor also writes the palette to ~/.cache/hyprskin (pywal's colors.json, palette.json with Material and wallbash roles, colors.css, colors.scss, colors.sh) and renders your templates from ~/.config/hyprskin/templates, using {{primary}}, {{on_surface}}, {{color4}}, {{dcol_pry1}} and the like. Mode, style and accent re-theme straight away while the wallpaper theme is active. Picking a regular Omarchy theme works as usual; the next auto-change switches back to wallpaper colors. Choose which parts follow the wallpaper under Look › Apply to."
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."

// How a new wallpaper arrives, and how it fills the screen.
Flickable {
  id: page

  property var hub
  property var store
  property var launcher

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  readonly property string type: page.store.transition.type || "grow"

  readonly property var styles: [
    { value: "grow", label: "Grow", glyph: "◉", description: "Circle expanding from the origin" },
    { value: "outer", label: "Outer", glyph: "◎", description: "Iris closing in from the edges" },
    { value: "wipe", label: "Wipe", glyph: "▶", description: "Hard edge sweeping across" },
    { value: "slant", label: "Slant", glyph: "◢", description: "The stock Omarchy diagonal reveal" },
    { value: "blinds", label: "Blinds", glyph: "☰", description: "14 slats opening together" },
    { value: "fade", label: "Fade", glyph: "◐", description: "Cross-fade" },
    { value: "blur", label: "Blur", glyph: "◌", description: "The new image sharpens out of a blur" },
    { value: "zoom", label: "Zoom", glyph: "⊕", description: "Old zooms out, new settles in" },
    { value: "slide", label: "Slide", glyph: "⇥", description: "New slides in over the old" },
    { value: "push", label: "Push", glyph: "⇉", description: "New pushes the old off-screen" },
    { value: "random", label: "Random", glyph: "⚄", description: "A different one each time" },
    { value: "none", label: "None", glyph: "■", description: "Instant" }
  ]

  ColumnLayout {
    id: column
    width: page.width
    spacing: Style.space(14)

    PageHeader {
      Layout.fillWidth: true
      title: "Transitions"
      subtitle: "Pick how wallpapers change. Applies to every change: from Studio, auto-change, the background switcher and omarchy theme set."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

      Button {
        text: "Try it"
        iconText: String.fromCodePoint(0xF040A)
        tooltipText: "Switch to the next wallpaper to see the transition"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        iconSpinning: page.store.applying && page.store.busyTarget === "next"
        onClicked: page.store.runAction(["next"])
      }
    }

    SectionLabel { Layout.fillWidth: true; text: "Style"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    GridLayout {
      Layout.fillWidth: true
      columns: Math.max(3, Math.floor(page.width / Style.space(170)))
      columnSpacing: Style.space(8)
      rowSpacing: Style.space(8)

      Repeater {
        model: page.styles
        ActionCard {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: Style.space(84)
          glyph: modelData.glyph
          title: modelData.label
          description: modelData.description
          highlighted: page.type === modelData.value
          badge: page.type === modelData.value ? "✓ in use" : ""
          foreground: page.hub.fg
          accent: page.hub.accent
          fontFamily: page.hub.fontFamily
          onClicked: page.store.setOption("transition.type", modelData.value)
        }
      }
    }

    SectionLabel { Layout.fillWidth: true; text: "Motion"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    SettingRow {
      Layout.fillWidth: true
      label: "Duration"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      PanelSlider {
        id: durationSlider
        width: Style.space(320)
        anchors.verticalCenter: parent.verticalCenter
        minimum: 100
        maximum: 3000
        step: 50
        integer: true
        trackColor: Util.alpha(page.hub.fg, 0.18)
        fillColor: page.hub.accent
        knobColor: page.hub.fg
        value: Number(page.store.transition.duration) || 900
        onReleased: function(value) { page.store.setOption("transition.duration", Math.round(value)) }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(durationSlider.liveValue) + " ms"
        color: page.hub.fg
        font.family: page.hub.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    SettingRow {
      Layout.fillWidth: true
      label: "Easing"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      Dropdown {
        width: Style.space(180)
        showLabel: false
        options: ["InOutCubic", "OutCubic", "OutQuint", "OutExpo", "InOutExpo", "InOutSine", "OutBack", "OutBounce", "Linear"]
        value: page.store.transition.easing || "InOutCubic"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        onChanged: function(v) { page.store.setOption("transition.easing", v) }
      }
    }

    SettingRow {
      Layout.fillWidth: true
      label: "Direction"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      visible: ["wipe", "slide", "push", "blinds", "random"].indexOf(page.type) !== -1
      ButtonGroup {
        options: ["left", "right", "up", "down", "random"]
        value: page.store.transition.direction || "left"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setOption("transition.direction", v) }
      }
    }

    SettingRow {
      Layout.fillWidth: true
      label: "Origin"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      visible: ["grow", "outer", "zoom", "random"].indexOf(page.type) !== -1
      ButtonGroup {
        options: ["center", "top-left", "top-right", "bottom-left", "bottom-right", "random"]
        value: page.store.transition.position || "center"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setOption("transition.position", v) }
      }
    }

    SectionLabel { Layout.fillWidth: true; text: "Fill"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    SettingRow {
      Layout.fillWidth: true
      label: "Fit"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      ButtonGroup {
        options: [
          { value: "crop", label: "Crop", tooltip: "Cover the screen" },
          { value: "fit", label: "Fit", tooltip: "Letterboxed in the theme background" },
          { value: "stretch", label: "Stretch" },
          { value: "center", label: "Center", tooltip: "Native size" },
          { value: "tile", label: "Tile" }
        ]
        value: page.store.cfg.fill || "crop"
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        fontSize: Style.font.bodySmall
        onChanged: function(v) { page.store.setOption("fill", v) }
      }
    }
  }
}

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../data/Presets.js" as P

// Preset layouts, screen position, and the bar's outer geometry.
Flickable {
  id: page

  property var ctl

  contentWidth: width
  contentHeight: col.implicitHeight + 10
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  function sig(layout) {
    var out = [], lanes = ["left", "center", "right"]
    for (var l = 0; l < 3; l++) {
      var a = layout[lanes[l]] || []
      out.push(a.map(function(e) { return e.id }).join(","))
    }
    return out.join("|")
  }

  readonly property string currentSig: sig(ctl.cfg.layout)

  Column {
    id: col
    width: page.width
    spacing: 14

    Text {
      text: "POSITION"
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      font.letterSpacing: 2
    }

    Row {
      spacing: 8
      Repeater {
        model: [
          { id: "top", label: "Top", glyph: "▔" },
          { id: "bottom", label: "Bottom", glyph: "▁" },
          { id: "left", label: "Left", glyph: "▏" },
          { id: "right", label: "Right", glyph: "▕" }
        ]
        OButton {
          text: modelData.label
          glyph: modelData.glyph
          active: page.ctl.cfg.position === modelData.id
          onClicked: page.ctl.setPosition(modelData.id)
        }
      }
    }

    Row {
      spacing: 36
      OSlider {
        width: 220
        label: "Float"
        from: 0; to: 16; step: 1; unit: "px"
        value: page.ctl.cfg.style && page.ctl.cfg.style.float !== undefined ? page.ctl.cfg.style.float : 0
        onMoved: function(v) { page.ctl.setStyle("float", v === 0 ? null : v) }
      }
      OSlider {
        width: 220
        label: "Edge padding"
        from: 0; to: 24; step: 1; unit: "px"
        value: page.ctl.cfg.style && page.ctl.cfg.style.edge !== undefined ? page.ctl.cfg.style.edge : (page.ctl.cfg.style && page.ctl.cfg.style.shape && page.ctl.cfg.style.shape !== "none" ? 0 : 8)
        onMoved: function(v) { page.ctl.setStyle("edge", v) }
      }
      OToggle {
        width: 200
        label: "Transparent bar"
        checked: page.ctl.cfg.transparent
        onToggled: function(v) { page.ctl.setTransparent(v) }
      }
    }

    Text {
      text: "LAYOUT PRESETS"
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      font.letterSpacing: 2
    }

    Flow {
      width: page.width
      spacing: 12

      Repeater {
        model: P.LAYOUTS

        Rectangle {
          readonly property bool current: page.sig(modelData.layout) === page.currentSig
          width: Math.floor((page.width - 12) / 2)
          height: 104
          color: mouse.containsMouse ? Commons.Color.menu.selectedBackground : "transparent"
          border.width: current ? 2 : 1
          border.color: current ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.5)

          MiniBar {
            x: 10; y: 10
            width: parent.width - 20
            cfg: ({ layout: modelData.layout, style: page.ctl.cfg.style, centerAnchor: modelData.anchor })
            themeColors: page.ctl.themeColors
            defaults: page.ctl.defaults
            segH: 20
            fontPx: 11
          }
          Text {
            x: 12
            y: parent.height - 40
            text: modelData.label
            color: current ? Commons.Color.accent : Commons.Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            x: 12
            y: parent.height - 22
            text: modelData.desc
            color: Commons.Color.muted
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body - 1
          }
          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.ctl.applyLayoutPreset(modelData)
          }
        }
      }
    }
  }
}

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

  property string query: ""
  readonly property bool searching: query.trim() !== ""
  // HANCORE is long; it starts folded.
  property var collapsed: ({ hancore: true })

  function toggle(id) {
    var c = JSON.parse(JSON.stringify(collapsed))
    c[id] = c[id] !== true
    collapsed = c
  }

  // Presets whose name, description or id contains every word typed.
  function matches(list) {
    var words = query.trim().toLowerCase().split(/\s+/), out = []
    for (var i = 0; i < list.length; i++) {
      var t = list[i], hay = (t.label + " " + (t.desc || "") + " " + t.id).toLowerCase(), ok = true
      for (var w = 0; w < words.length; w++) if (words[w] !== "" && hay.indexOf(words[w]) === -1) { ok = false; break }
      if (ok) out.push(t)
    }
    return out
  }

  readonly property var sections: [
    { id: "presets", title: "PRESETS", hint: "", items: matches(P.LAYOUTS.filter(function(l) { return l.id.indexOf("jk-") !== 0 })) },
    { id: "jakoolit", title: "JAKOOLIT", hint: "arrangements from JaKooLit's Hyprland-Dots", items: matches(P.LAYOUTS.filter(function(l) { return l.id.indexOf("jk-") === 0 })) },
    { id: "hancore", title: "HANCORE", hint: "arrangements from HANCORE-linux/waybar-themes", items: matches(P.HANCORE_LAYOUTS) }
  ]

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

    Rectangle {
      width: page.width
      height: 28
      color: "transparent"
      border.width: 1
      border.color: layoutSearch.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
      Text {
        visible: layoutSearch.text === ""
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        text: "Search " + (P.ALL_LAYOUTS.length) + " layouts"
        color: Util.alpha(Commons.Color.muted, 0.8)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }
      TextInput {
        id: layoutSearch
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Commons.Color.menu.text
        selectionColor: Commons.Color.accent
        selectedTextColor: Commons.Color.background
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        onTextChanged: page.query = text
      }
    }

    Repeater {
      model: page.sections

      Column {
        id: section
        required property var modelData
        readonly property bool open: page.searching || page.collapsed[modelData.id] !== true
        width: page.width
        spacing: 10
        visible: !page.searching || modelData.items.length > 0

        Rectangle {
          width: parent.width
          height: 26
          color: hdrMouse.containsMouse ? Commons.Color.menu.selectedBackground : "transparent"
          Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            spacing: 8
            Text {
              text: section.open ? "\u{F0140}" : "\u{F0142}"
              color: Commons.Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            Text {
              text: section.modelData.title + "  ·  " + section.modelData.items.length
              color: Commons.Color.menu.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body - 1
              font.bold: true
              font.letterSpacing: 1.5
            }
            Text {
              visible: section.modelData.hint !== "" && !page.searching
              text: section.modelData.hint
              color: Commons.Color.muted
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body - 2
            }
          }
          MouseArea {
            id: hdrMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.toggle(section.modelData.id)
          }
        }

        Flow {
          visible: section.open
          width: page.width
          spacing: 12

          Repeater {
            model: section.open ? section.modelData.items : []

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
              // Presets that also move the bar say which edge.
              Text {
                visible: !!modelData.position
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: parent.height - 38
                text: modelData.position ? "moves bar to " + modelData.position : ""
                color: Commons.Color.muted
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body - 2
              }
              Text {
                x: 12
                y: parent.height - 22
                width: parent.width - 24
                elide: Text.ElideRight
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
  }
}

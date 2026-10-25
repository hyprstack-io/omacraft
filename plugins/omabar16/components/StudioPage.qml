import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../data/Presets.js" as P
import "../data/Icons.js" as I

// Build your own look: pick a part of the bar (here, or by clicking it in the
// preview), set its colour, tune the shape, save the result as a theme.
Item {
  id: page

  property var ctl

  readonly property string part: ctl.selectedPart
  readonly property var style: ctl.cfg.style || ({})
  readonly property string shape: style.shape || "none"
  readonly property bool solid: style.solid !== false
  readonly property bool iconable: I.ICONABLE.indexOf(modId) !== -1
  readonly property string modId: part.indexOf("module:") === 0 ? part.substr(7) : ""

  function partLabel(id) {
    for (var i = 0; i < ctl.parts.length; i++) if (ctl.parts[i].id === id) return ctl.parts[i].label
    return id
  }

  RowLayout {
    anchors.fill: parent
    spacing: 16

    // ---- parts list
    Flickable {
      Layout.preferredWidth: 180
      Layout.minimumWidth: 180
      Layout.maximumWidth: 180
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: partsCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: partsCol
        width: parent.width
        spacing: 2

        Repeater {
          model: page.ctl.parts

          Column {
            width: partsCol.width
            spacing: 2

            Text {
              visible: index === 0 || page.ctl.parts[index - 1].group !== modelData.group
              topPadding: index === 0 ? 0 : 10
              bottomPadding: 3
              text: modelData.group
              color: Commons.Color.muted
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body - 2
              font.letterSpacing: 2
            }
            Rectangle {
              width: parent.width
              height: 30
              color: page.part === modelData.id ? Util.alpha(Commons.Color.accent, 0.16) : (pmouse.containsMouse ? Commons.Color.menu.selectedBackground : "transparent")
              Rectangle { width: 3; height: parent.height; color: Commons.Color.accent; visible: page.part === modelData.id }
              Rectangle {
                x: 12; anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                color: page.ctl.partColor(modelData.id)
                border.width: 1
                border.color: Util.alpha(Commons.Color.menu.border, 0.8)
              }
              Text {
                x: 34
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 60
                elide: Text.ElideRight
                text: modelData.label
                color: page.part === modelData.id ? Commons.Color.accent : Commons.Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
              }
              Rectangle {
                visible: page.ctl.partOverridden(modelData.id)
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: Commons.Color.accent
              }
              MouseArea {
                id: pmouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.ctl.selectedPart = modelData.id
              }
            }
          }
        }
      }
    }

    Rectangle { Layout.fillHeight: true; width: 1; color: Util.alpha(Commons.Color.menu.border, 0.35) }

    // ---- colour picker
    ColumnLayout {
      Layout.preferredWidth: 340
      Layout.minimumWidth: 340
      Layout.maximumWidth: 340
      Layout.fillHeight: true
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: page.partLabel(page.part).toUpperCase()
          color: Commons.Color.accent
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.title
          font.bold: true
          font.letterSpacing: 1.5
        }
        Item { Layout.fillWidth: true }
        Text {
          text: page.ctl.partOverridden(page.part) ? "CUSTOM" : "FROM THEME"
          color: Commons.Color.muted
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 2
          font.letterSpacing: 1.5
        }
      }

      HexColorPicker {
        Layout.fillWidth: true
        value: page.ctl.partColor(page.part)
        themeSwatches: page.ctl.themeSwatches
        onPicked: function(hex) { page.ctl.setPartColor(page.part, hex) }
      }

      OButton {
        text: page.part.indexOf("pal:") === 0 ? "Reset whole palette" : "Follow theme"
        glyph: "\u{F0709}"
        subtle: true
        enabled: page.ctl.partOverridden(page.part)
        opacity: enabled ? 1 : 0.4
        onClicked: page.ctl.clearPart(page.part)
      }
      Item { Layout.fillHeight: true }
    }

    Rectangle { Layout.fillHeight: true; width: 1; color: Util.alpha(Commons.Color.menu.border, 0.35) }

    // ---- shape + save
    Flickable {
      Layout.fillWidth: true
      Layout.minimumWidth: 240
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: shapeCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: shapeCol
        width: parent.width
        spacing: 12

        // ---- per-module options (when a module is selected)
        ColumnLayout {
          id: modOpts
          visible: page.modId !== ""
          Layout.fillWidth: true
          spacing: 10

          readonly property var entry: page.modId !== "" ? page.ctl.moduleEntry(page.modId) : null

          Text { text: page.partLabel(page.part).toUpperCase() + " OPTIONS"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }

          // Clock: quick format presets, plus a custom Qt format string.
          Flow {
            visible: page.modId === "omarchy.clock"
            Layout.fillWidth: true
            spacing: 6
            Repeater {
              model: [
                { label: "Day + 24h", f: "dddd HH:mm" }, { label: "24h", f: "HH:mm" },
                { label: "12h", f: "h:mm AP" }, { label: "Date + time", f: "ddd d MMM  HH:mm" },
                { label: "Seconds", f: "HH:mm:ss" }
              ]
              OButton {
                text: modelData.label
                active: modOpts.entry && modOpts.entry.format === modelData.f
                onClicked: {
                  page.ctl.setEntryOption(page.modId, "format", modelData.f)
                  var v = modelData.f.indexOf("HH") !== -1 || modelData.f.indexOf("h:") !== -1 ? "HH\n—\nmm" : ""
                  page.ctl.setEntryOption(page.modId, "verticalFormat", v)
                }
              }
            }
          }
          Rectangle {
            visible: page.modId === "omarchy.clock"
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "transparent"
            border.width: 1
            border.color: fmtField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
            TextInput {
              id: fmtField
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: TextInput.AlignVCenter
              color: Commons.Color.menu.text
              selectionColor: Commons.Color.accent
              selectedTextColor: Commons.Color.background
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              text: modOpts.entry && modOpts.entry.format ? modOpts.entry.format : ""
              onAccepted: page.ctl.setEntryOption(page.modId, "format", text)
            }
            Text {
              visible: fmtField.text === ""
              anchors.verticalCenter: parent.verticalCenter
              x: 10
              text: "Custom format, Enter to apply"
              color: Util.alpha(Commons.Color.muted, 0.8)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }
          }

          OSlider {
            visible: page.modId === "omarchy.spacer"
            Layout.fillWidth: true
            label: "Spacer width"
            from: 2; to: 80; step: 1; unit: "px"
            value: modOpts.entry && modOpts.entry.size !== undefined ? modOpts.entry.size : 12
            onMoved: function(v) { page.ctl.setEntryOption(page.modId, "size", v) }
          }

          IconChooser {
            visible: page.iconable
            Layout.fillWidth: true
            ctl: page.ctl
            modId: page.modId
          }

          Text {
            visible: page.modId !== "omarchy.clock" && page.modId !== "omarchy.spacer" && !page.iconable
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Colour is set on the left. This module has no other options."
            color: Util.alpha(Commons.Color.muted, 0.85)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body - 1
          }

          Rectangle { Layout.fillWidth: true; height: 1; color: Util.alpha(Commons.Color.menu.border, 0.35) }
        }

        Text { text: "SHAPE"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        Flow {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: [
              { id: "arrow", label: "Chevron", glyph: "\u{F0142}" }, { id: "slant", label: "Slant", glyph: "╱" },
              { id: "backslant", label: "Back slant", glyph: "╲" }, { id: "trapezoid", label: "Trapezoid", glyph: "⏢" },
              { id: "hex", label: "Hexagon", glyph: "⬡" },
              { id: "round", label: "Pill", glyph: "◖" }, { id: "block", label: "Block", glyph: "■" },
              { id: "leaf", label: "Leaf", glyph: "◩" }, { id: "tab", label: "Tab", glyph: "⌓" },
              { id: "underline", label: "Underline", glyph: "▁" },
              { id: "none", label: "None", glyph: "○" }
            ]
            OButton {
              text: modelData.label
              glyph: modelData.glyph
              active: page.shape === modelData.id
              onClicked: page.ctl.setStyle("shape", modelData.id)
            }
          }
        }

        Text { text: "FILL"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        Row {
          spacing: 6
          OButton { text: "Solid"; active: page.solid; onClicked: page.ctl.setStyle("solid", true) }
          OButton { text: "Tinted"; active: !page.solid; onClicked: page.ctl.setStyle("solid", false) }
          OButton { text: "Cycle"; active: page.style.colors !== "mono"; onClicked: page.ctl.setStyle("colors", "cycle") }
          OButton { text: "Mono"; active: page.style.colors === "mono"; onClicked: page.ctl.setStyle("colors", "mono") }
        }

        OSlider {
          visible: !page.solid
          Layout.fillWidth: true
          label: "Tint strength"
          from: 0.05; to: 0.8; step: 0.01; decimals: 2
          value: page.style.tint === undefined ? 0.3 : page.style.tint
          onMoved: function(v) { page.ctl.setStyle("tint", v) }
        }
        OSlider {
          Layout.fillWidth: true
          label: "Gap"
          from: 0; to: 12; step: 1; unit: "px"
          value: page.style.gap === undefined ? 1 : page.style.gap
          onMoved: function(v) { page.ctl.setStyle("gap", v) }
        }
        OSlider {
          Layout.fillWidth: true
          label: "Inset"
          from: 0; to: 8; step: 1; unit: "px"
          value: page.style.inset === undefined ? 0 : page.style.inset
          onMoved: function(v) { page.ctl.setStyle("inset", v) }
        }
        OSlider {
          visible: page.shape === "arrow"
          Layout.fillWidth: true
          label: "Chevron depth"
          from: 0.2; to: 0.7; step: 0.02; decimals: 2
          value: page.style.depth === undefined ? 0.42 : page.style.depth
          onMoved: function(v) { page.ctl.setStyle("depth", v) }
        }

        Text { text: "SIZE & TYPE"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        OSlider {
          Layout.fillWidth: true
          label: "Bar thickness"
          from: 16; to: 64; step: 1; unit: "px"
          value: page.style.size === undefined ? (page.ctl.cfg.position === "left" || page.ctl.cfg.position === "right" ? Style.bar.sizeVertical : Style.bar.sizeHorizontal) : page.style.size
          onMoved: function(v) { page.ctl.setStyle("size", v) }
        }
        OSlider {
          visible: page.shape === "block"
          Layout.fillWidth: true
          label: "Corner radius"
          from: 0; to: 20; step: 1; unit: "px"
          value: page.style.radius === undefined ? Style.cornerRadius : page.style.radius
          onMoved: function(v) { page.ctl.setStyle("radius", v) }
        }
        OSlider {
          Layout.fillWidth: true
          label: "Segment padding"
          from: 0; to: 16; step: 1; unit: "px"
          value: page.style.pad === undefined ? 3 : page.style.pad
          onMoved: function(v) { page.ctl.setStyle("pad", v) }
        }
        Text { text: "FONT"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "transparent"
            border.width: 1
            border.color: fontField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
            Text {
              visible: fontField.text === ""
              anchors.verticalCenter: parent.verticalCenter
              x: 10
              text: "System font (default)"
              color: Util.alpha(Commons.Color.muted, 0.8)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }
            TextInput {
              id: fontField
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: TextInput.AlignVCenter
              color: Commons.Color.menu.text
              selectionColor: Commons.Color.accent
              selectedTextColor: Commons.Color.background
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              text: page.style.fontFamily || ""
              onAccepted: page.ctl.setStyle("fontFamily", text.trim() === "" ? null : text.trim())
            }
          }
          OButton { text: "Apply"; onClicked: page.ctl.setStyle("fontFamily", fontField.text.trim() === "" ? null : fontField.text.trim()) }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Util.alpha(Commons.Color.menu.border, 0.35) }

        Text { text: "SAVE AS THEME"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "transparent"
            border.width: 1
            border.color: nameField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)

            Text {
              visible: nameField.text === ""
              anchors.verticalCenter: parent.verticalCenter
              x: 10
              text: "Theme name"
              color: Util.alpha(Commons.Color.muted, 0.8)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }
            TextInput {
              id: nameField
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: TextInput.AlignVCenter
              color: Commons.Color.menu.text
              selectionColor: Commons.Color.accent
              selectedTextColor: Commons.Color.background
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              maximumLength: 32
              onAccepted: if (page.ctl.saveTheme(text)) text = ""
            }
          }
          OButton {
            text: "Save"
            glyph: "\u{F0193}"
            onClicked: if (page.ctl.saveTheme(nameField.text)) nameField.text = ""
          }
        }
        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "Saved themes appear on the Themes tab and can be applied to any layout."
          color: Util.alpha(Commons.Color.muted, 0.85)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 1
        }
      }
    }
  }
}

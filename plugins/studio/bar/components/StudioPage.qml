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
  readonly property string modId: part.indexOf("module:") === 0 ? part.substr(7) : ""
  readonly property bool iconable: I.iconable(modId)
  readonly property var modEntry: modId !== "" ? ctl.moduleEntry(modId) : null

  // A module has three colours: its segment, its icon & text, its hover.
  property string modTarget: "segment"
  onPartChanged: modTarget = "segment"
  readonly property string colorPart: modId === "" || modTarget === "segment" ? part
    : (modTarget === "text" ? "moduletext:" + modId : "modulehover:" + modId)

  function entryValue(key, fallback) {
    var e = page.modEntry
    return e && e[key] !== undefined && e[key] !== null ? e[key] : fallback
  }

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
          text: page.ctl.partOverridden(page.colorPart) ? "CUSTOM" : "FROM THEME"
          color: Commons.Color.muted
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 2
          font.letterSpacing: 1.5
        }
      }

      Row {
        visible: page.modId !== ""
        spacing: 6
        OButton { text: "Segment"; active: page.modTarget === "segment"; onClicked: page.modTarget = "segment" }
        OButton { text: "Icon & text"; active: page.modTarget === "text"; onClicked: page.modTarget = "text" }
        OButton { text: "Hover"; active: page.modTarget === "hover"; onClicked: page.modTarget = "hover" }
      }

      HexColorPicker {
        Layout.fillWidth: true
        value: page.ctl.partColor(page.colorPart)
        themeSwatches: page.ctl.themeSwatches
        onPicked: function(hex) { page.ctl.setPartColor(page.colorPart, hex) }
      }

      OButton {
        text: page.colorPart.indexOf("pal:") === 0 ? "Reset whole palette"
          : (page.colorPart.indexOf("modulehover:") === 0 ? "Use the bar's hover colour"
          : (page.colorPart.indexOf("moduletext:") === 0 ? "Use the bar's text colour" : "Follow theme"))
        glyph: "\u{F0709}"
        subtle: true
        enabled: page.ctl.partOverridden(page.colorPart)
        opacity: enabled ? 1 : 0.4
        onClicked: page.ctl.clearPart(page.colorPart)
      }

      Text {
        visible: page.part === "hoverColor" || page.modTarget === "hover"
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Hovered modules blend toward this colour. Set how strongly under HOVER & OPACITY on the right."
        color: Util.alpha(Commons.Color.muted, 0.85)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body - 2
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

          Text { visible: page.iconable; text: "Icon"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body }
          IconChooser {
            visible: page.iconable
            Layout.fillWidth: true
            ctl: page.ctl
            modId: page.modId
            previewFont: page.entryValue("iconFont", "") || page.style.iconFont || page.style.fontFamily || Style.font.family
          }
          Text {
            visible: page.iconable && I.stateful(page.modId)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "This widget changes its icon with its state (muted, offline, charging). A custom icon shows all the time instead."
            color: Util.alpha(Commons.Color.muted, 0.85)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body - 2
          }
          Text { visible: page.iconable && page.entryValue("icon", "") !== ""; text: "Icon font"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body }
          FontPicker {
            visible: page.iconable && page.entryValue("icon", "") !== ""
            Layout.fillWidth: true
            families: page.ctl.fontFamilies
            defaultLabel: "Bar icon font"
            sample: page.entryValue("icon", "")
            value: page.entryValue("iconFont", "")
            onPicked: function(f) { page.ctl.setEntryOption(page.modId, "iconFont", f) }
          }

          Text { text: "Text font"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body }
          FontPicker {
            Layout.fillWidth: true
            families: page.ctl.fontFamilies
            defaultLabel: "Bar font"
            value: page.entryValue("font", "")
            onPicked: function(f) { page.ctl.setEntryOption(page.modId, "font", f) }
          }

          OSlider {
            Layout.fillWidth: true
            label: "Opacity"
            from: 0.1; to: 1; step: 0.05; decimals: 2
            value: Number(page.entryValue("opacity", 1))
            onMoved: function(v) { page.ctl.setEntryOption(page.modId, "opacity", v >= 1 ? null : v) }
          }
          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Colours for this module's segment, icon & text and hover are on the left. Font and colour apply to widgets drawn as a single button; workspaces, tray and media keep their own."
            color: Util.alpha(Commons.Color.muted, 0.85)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body - 2
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

        Text { text: "CONTRAST & DEPTH"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        OSlider {
          Layout.fillWidth: true
          label: "Minimum text contrast"
          from: 0; to: 10; step: 0.5; decimals: 1; unit: ":1"
          value: page.style.minContrast === undefined ? 4.5 : page.style.minContrast
          onMoved: function(v) { page.ctl.setStyle("minContrast", v) }
        }
        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "Segments too close to the text color are darkened or lightened until the text reaches this ratio. 4.5 is WCAG AA, 7 is AAA, 0 turns it off."
          color: Util.alpha(Commons.Color.muted, 0.85)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 2
        }
        OSlider {
          Layout.fillWidth: true
          label: "Outline"
          from: 0; to: 4; step: 1; unit: "px"
          value: page.style.outline === undefined ? 0 : page.style.outline
          onMoved: function(v) { page.ctl.setStyle("outline", v === 0 ? null : v) }
        }
        OSlider {
          Layout.fillWidth: true
          label: "Shadow"
          from: 0; to: 1; step: 0.05; decimals: 2
          value: page.style.shadow === undefined ? 0 : page.style.shadow
          onMoved: function(v) { page.ctl.setStyle("shadow", v === 0 ? null : v) }
        }
        OSlider {
          Layout.fillWidth: true
          label: "Backdrop"
          from: 0; to: 1; step: 0.05; decimals: 2
          value: page.style.backdrop === undefined ? 0 : page.style.backdrop
          onMoved: function(v) { page.ctl.setStyle("backdrop", v === 0 ? null : v) }
        }
        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "Backdrop draws the bar background behind the segments when the bar is transparent or floating. Pick the outline color under BAR › Outline on the left; wallpaper colors set it to stand out from the wallpaper."
          color: Util.alpha(Commons.Color.muted, 0.85)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 2
        }

        Text { text: "HOVER & OPACITY"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        OSlider {
          Layout.fillWidth: true
          label: "Hover strength"
          from: 0; to: 1; step: 0.05; decimals: 2
          value: page.style.hoverOpacity === undefined ? (page.shape === "none" ? 0.14 : 0.35) : page.style.hoverOpacity
          onMoved: function(v) { page.ctl.setStyle("hoverOpacity", v) }
        }
        OSlider {
          visible: page.shape !== "none"
          Layout.fillWidth: true
          label: "Segment opacity"
          from: 0.1; to: 1; step: 0.05; decimals: 2
          value: page.style.segmentOpacity === undefined ? 1 : page.style.segmentOpacity
          onMoved: function(v) { page.ctl.setStyle("segmentOpacity", v >= 1 ? null : v) }
        }
        // A floating or transparent bar paints no background of its own, only
        // the backdrop, so there the slider drives that instead.
        OSlider {
          readonly property bool viaBackdrop: page.ctl.cfg.transparent === true || (page.shape !== "none" && Number(page.style.float || 0) > 0)
          Layout.fillWidth: true
          label: viaBackdrop ? "Bar background opacity (backdrop)" : "Bar background opacity"
          from: 0; to: 1; step: 0.05; decimals: 2
          value: viaBackdrop ? (page.style.backdrop === undefined ? 0 : page.style.backdrop)
            : (page.style.barOpacity === undefined ? 1 : page.style.barOpacity)
          onMoved: function(v) {
            if (viaBackdrop) page.ctl.setStyle("backdrop", v === 0 ? null : v)
            else page.ctl.setStyle("barOpacity", v >= 1 ? null : v)
          }
        }
        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "Pick the hover colour under BAR › Hover on the left, or per module. Without one, segments just lighten on hover and a bar without segments shows a faint highlight once you set a strength. Each module's own opacity is in its options."
          color: Util.alpha(Commons.Color.muted, 0.85)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 2
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
        Text { text: "FONTS"; color: Commons.Color.muted; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body - 2; font.letterSpacing: 2 }
        Text { text: "Bar font"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body }
        FontPicker {
          Layout.fillWidth: true
          families: page.ctl.fontFamilies
          defaultLabel: "System font (default)"
          value: page.style.fontFamily || ""
          onPicked: function(f) { page.ctl.setStyle("fontFamily", f === "" ? null : f) }
        }
        Text { text: "Icon font"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body }
        FontPicker {
          Layout.fillWidth: true
          families: page.ctl.fontFamilies
          defaultLabel: "Same as the bar font"
          sample: "\u{F0954} \u{F057E} \u{F05A9}"
          value: page.style.iconFont || ""
          onPicked: function(f) { page.ctl.setStyle("iconFont", f === "" ? null : f) }
        }
        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "The icon font draws custom module icons; pick a Nerd Font so every glyph has a shape. Each module can also have its own text and icon font."
          color: Util.alpha(Commons.Color.muted, 0.85)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 2
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

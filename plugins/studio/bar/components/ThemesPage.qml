import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../data/Presets.js" as P

// Preset and user themes, each previewed on the same compact layout.
Flickable {
  id: page

  property var ctl

  contentWidth: width
  contentHeight: col.implicitHeight + 10
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  readonly property var sample: P.LAYOUTS[1]

  property string query: ""
  readonly property bool searching: query.trim() !== ""
  // HANCORE is long; it starts folded.
  property var collapsed: ({ hancore: true })

  function toggle(id) {
    var c = JSON.parse(JSON.stringify(collapsed))
    c[id] = c[id] !== true
    collapsed = c
  }

  // Themes whose name, description or id contains every word typed.
  function matches(list) {
    var words = query.trim().toLowerCase().split(/\s+/), out = []
    for (var i = 0; i < list.length; i++) {
      var t = list[i], hay = (t.label + " " + (t.desc || "") + " " + t.id).toLowerCase(), ok = true
      for (var w = 0; w < words.length; w++) if (words[w] !== "" && hay.indexOf(words[w]) === -1) { ok = false; break }
      if (ok) out.push(t)
    }
    return out
  }

  component ThemeCard: Rectangle {
    id: card
    property var theme
    readonly property bool current: page.ctl.activeThemeId === theme.id

    width: Math.floor((page.width - 24) / 3)
    height: 112
    color: mouse.containsMouse ? Commons.Color.menu.selectedBackground : "transparent"
    border.width: current ? 2 : 1
    border.color: current ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.5)

    MiniBar {
      x: 8; y: 10
      width: parent.width - 16
      cfg: ({ layout: page.sample.layout, style: card.theme.style, centerAnchor: page.sample.anchor })
      themeColors: page.ctl.themeColors
      defaults: page.ctl.defaults
      segH: 20
      fontPx: 11
    }
    Text {
      x: 12
      y: parent.height - 44
      text: card.theme.label
      color: card.current ? Commons.Color.accent : Commons.Color.menu.text
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
    Text {
      x: 12
      y: parent.height - 24
      width: parent.width - 24
      elide: Text.ElideRight
      text: card.theme.desc
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 1
    }
    Text {
      visible: card.current
      anchors.right: parent.right
      anchors.margins: 10
      y: parent.height - 44
      text: "ACTIVE"
      color: Commons.Color.accent
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      font.letterSpacing: 1.5
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: page.ctl.applyTheme(card.theme)
    }
    OButton {
      visible: mouse.containsMouse
      anchors.right: parent.right
      anchors.rightMargin: card.theme.user === true ? 76 : 6
      anchors.top: parent.top
      anchors.topMargin: 6
      implicitHeight: 22
      padX: 8
      text: "Export"
      subtle: true
      onClicked: page.ctl.exportThemes(card.theme)
    }
    OButton {
      visible: card.theme.user === true && mouse.containsMouse
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 6
      implicitHeight: 22
      padX: 8
      text: "Delete"
      danger: true
      onClicked: page.ctl.deleteTheme(card.theme.id)
    }
  }

  Column {
    id: col
    width: page.width
    spacing: 12

    // ---- search
    Rectangle {
      width: page.width
      height: 28
      color: "transparent"
      border.width: 1
      border.color: searchField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
      Text {
        visible: searchField.text === ""
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        text: "Search themes"
        color: Util.alpha(Commons.Color.muted, 0.8)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }
      TextInput {
        id: searchField
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 34
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Commons.Color.menu.text
        selectionColor: Commons.Color.accent
        selectedTextColor: Commons.Color.background
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        onTextChanged: page.query = text
      }
      Text {
        visible: searchField.text !== ""
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0156}"
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: searchField.text = "" }
      }
    }

    Text {
      visible: page.searching && page.matches(page.ctl.allThemes).length === 0
      text: "No themes match \u201c" + page.query.trim() + "\u201d."
      color: Util.alpha(Commons.Color.muted, 0.8)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
    }

    // ---- collapsible sections
    Repeater {
      model: [
        { id: "presets", title: "PRESETS", hint: "click to apply, colours follow your Omarchy theme unless the preset sets its own", items: page.matches(P.THEMES) },
        { id: "jakoolit", title: "JAKOOLIT", hint: "waybar looks from JaKooLit's Hyprland-Dots", items: page.matches(P.JAKOOLIT) },
        { id: "hancore", title: "HANCORE", hint: "waybar looks from HANCORE-linux/waybar-themes, most in your Omarchy theme colours", items: page.matches(P.HANCORE) },
        { id: "base16", title: "BASE16", hint: "A to Z", items: page.matches(P.BASE16) },
        { id: "mine", title: "YOUR THEMES", hint: "", items: page.matches(page.ctl.userThemes) }
      ]

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
            anchors.left: parent.left
            anchors.leftMargin: 4
            spacing: 8
            Text {
              text: section.open ? "\u{F0140}" : "\u{F0142}"
              color: Commons.Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: section.modelData.title + "  ·  " + section.modelData.items.length
              color: Commons.Color.muted
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body - 2
              font.letterSpacing: 2
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              visible: section.modelData.hint !== "" && !page.searching
              text: section.modelData.hint
              color: Util.alpha(Commons.Color.muted, 0.7)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body - 2
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          MouseArea {
            id: hdrMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !page.searching
            onClicked: page.toggle(section.modelData.id)
          }
        }
        Text {
          visible: section.open && section.modelData.id === "mine" && page.ctl.userThemes.length === 0
          text: "Nothing yet. Build a look in Studio and save it."
          color: Util.alpha(Commons.Color.muted, 0.8)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }
        Flow {
          visible: section.open
          width: page.width
          spacing: 12
          Repeater { model: section.modelData.items; ThemeCard { theme: modelData } }
        }
      }
    }

    Text {
      text: "IMPORT / EXPORT"
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      font.letterSpacing: 2
    }
    Row {
      spacing: 6
      OButton { text: "Export current look"; glyph: "\u{F0552}"; onClicked: page.ctl.exportCurrent() }
      OButton { text: "Export all my themes"; enabled: page.ctl.userThemes.length > 0; opacity: enabled ? 1 : 0.4; onClicked: page.ctl.exportThemes(null) }
    }
    RowLayout {
      width: page.width
      spacing: 8
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        color: "transparent"
        border.width: 1
        border.color: importField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
        Text {
          visible: importField.text === ""
          anchors.verticalCenter: parent.verticalCenter
          x: 10
          text: "Paste theme JSON or a file path, then Enter"
          color: Util.alpha(Commons.Color.muted, 0.8)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }
        TextInput {
          id: importField
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
          onAccepted: if (page.ctl.importText(text, false)) text = ""
        }
      }
      OButton { text: "Paste"; subtle: true; onClicked: { importField.paste() } }
      OButton { text: "Import"; onClicked: if (page.ctl.importText(importField.text, false)) importField.text = "" }
    }
    Text {
      width: page.width
      wrapMode: Text.WordWrap
      text: "Exports go to ~/.config/omarchy/omabar16/exports/ and are copied to the clipboard."
      color: Util.alpha(Commons.Color.muted, 0.85)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 1
    }
  }
}

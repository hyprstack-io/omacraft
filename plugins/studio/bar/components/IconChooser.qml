import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../data/Icons.js" as I

// Pick a bar icon from Font Awesome or Octicons (both ship inside Nerd Fonts),
// or paste any glyph or codepoint. Writes the glyph to the module's `icon`
// entry key; Default removes it.
ColumnLayout {
  id: chooser

  property var ctl
  property string modId: ""

  property string set: "fa"
  property string query: ""
  property string hoverName: ""
  // Font the icon is drawn in on the bar, so the preview matches.
  property string previewFont: Style.font.family

  readonly property var entry: modId !== "" ? ctl.moduleEntry(modId) : null
  readonly property string current: entry && typeof entry.icon === "string" ? entry.icon : ""
  readonly property var icons: I.filter(set, query)

  spacing: 8

  RowLayout {
    Layout.fillWidth: true
    spacing: 8
    Rectangle {
      width: 36; height: 36
      color: Util.alpha(Commons.Color.menu.text, 0.05)
      border.width: 1
      border.color: Util.alpha(Commons.Color.menu.border, 0.6)
      Text {
        anchors.centerIn: parent
        text: chooser.current !== "" ? chooser.current : "\u{F01C9}"
        color: chooser.current !== "" ? Commons.Color.accent : Commons.Color.muted
        font.family: chooser.previewFont
        font.pixelSize: 20
      }
    }
    Text {
      Layout.fillWidth: true
      elide: Text.ElideRight
      text: chooser.hoverName !== "" ? chooser.hoverName : (chooser.current !== "" ? "Custom icon" : "Module default")
      color: Commons.Color.menu.text
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
    }
    OButton {
      text: "Default"
      subtle: true
      enabled: chooser.current !== ""
      opacity: enabled ? 1 : 0.4
      onClicked: chooser.ctl.setEntryOption(chooser.modId, "icon", null)
    }
  }

  // Any glyph: paste it, or type its codepoint (f0954, U+F0954).
  RowLayout {
    Layout.fillWidth: true
    spacing: 8
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 28
      color: "transparent"
      border.width: 1
      border.color: glyphField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
      Text {
        visible: glyphField.text === ""
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        text: "Paste a glyph or codepoint (f0954)"
        color: Util.alpha(Commons.Color.muted, 0.8)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }
      TextInput {
        id: glyphField
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Commons.Color.menu.text
        selectionColor: Commons.Color.accent
        selectedTextColor: Commons.Color.background
        font.family: chooser.previewFont
        font.pixelSize: Style.font.body
        onAccepted: chooser.useTyped()
      }
    }
    Text {
      text: I.parseGlyph(glyphField.text)
      visible: text !== ""
      color: Commons.Color.accent
      font.family: chooser.previewFont
      font.pixelSize: 18
    }
    OButton { text: "Use"; enabled: I.parseGlyph(glyphField.text) !== ""; opacity: enabled ? 1 : 0.4; onClicked: chooser.useTyped() }
  }

  function useTyped() {
    var g = I.parseGlyph(glyphField.text)
    if (g === "") return
    chooser.ctl.setEntryOption(chooser.modId, "icon", g)
    glyphField.text = ""
  }

  Row {
    spacing: 6
    OButton { text: "Font Awesome"; active: chooser.set === "fa"; onClicked: chooser.set = "fa" }
    OButton { text: "Octicons"; active: chooser.set === "oct"; onClicked: chooser.set = "oct" }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 28
    color: "transparent"
    border.width: 1
    border.color: iconSearch.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
    Text {
      visible: iconSearch.text === ""
      anchors.verticalCenter: parent.verticalCenter
      x: 10
      text: "Search " + chooser.icons.length + " icons"
      color: Util.alpha(Commons.Color.muted, 0.8)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
    }
    TextInput {
      id: iconSearch
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
      onTextChanged: chooser.query = text
    }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 210
    color: Util.alpha(Commons.Color.menu.text, 0.025)
    border.width: 1
    border.color: Util.alpha(Commons.Color.menu.border, 0.45)
    clip: true

    GridView {
      id: grid
      anchors.fill: parent
      anchors.margins: 6
      cellWidth: 38
      cellHeight: 38
      model: chooser.icons
      boundsBehavior: Flickable.StopAtBounds
      cacheBuffer: 400

      delegate: Rectangle {
        required property var modelData
        width: grid.cellWidth - 2
        height: grid.cellHeight - 2
        color: modelData.char === chooser.current ? Util.alpha(Commons.Color.accent, 0.22) : (cell.containsMouse ? Commons.Color.menu.selectedBackground : "transparent")
        border.width: modelData.char === chooser.current ? 1 : 0
        border.color: Commons.Color.accent
        Text {
          anchors.centerIn: parent
          text: modelData.char
          color: modelData.char === chooser.current ? Commons.Color.accent : Commons.Color.menu.text
          font.family: Style.font.family
          font.pixelSize: 18
        }
        MouseArea {
          id: cell
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onContainsMouseChanged: {
            if (containsMouse) chooser.hoverName = modelData.name
            else if (chooser.hoverName === modelData.name) chooser.hoverName = ""
          }
          onClicked: chooser.ctl.setEntryOption(chooser.modId, "icon", modelData.char)
        }
      }
    }

    Text {
      visible: chooser.icons.length === 0
      anchors.centerIn: parent
      text: "No icons match."
      color: Util.alpha(Commons.Color.muted, 0.8)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
    }
  }
}

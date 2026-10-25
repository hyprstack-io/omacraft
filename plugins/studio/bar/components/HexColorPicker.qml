import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../data/Presets.js" as P

// Saturation/value square + hue strip + hex field + swatch chart.
// `value` is the colour shown; `picked(hex)` fires on every user change.
Item {
  id: picker

  property string value: "#89b4fa"
  property var themeSwatches: []
  property bool editable: true
  signal picked(string hex)

  property real hue: 0
  property real sat: 0
  property real val: 1
  property bool internal: false

  implicitWidth: 380
  implicitHeight: col.implicitHeight

  function syncFrom(hex) {
    if (!P.isHex(hex)) return
    var hsv = P.hexToHsv(hex)
    // Keep the hue while the colour is grey/black, or the strip would jump to red.
    if (hsv.s > 0.001 && hsv.v > 0.001) hue = hsv.h
    sat = hsv.s
    val = hsv.v
  }

  onValueChanged: if (!internal) { syncFrom(value); hexField.text = value.toUpperCase() }
  Component.onCompleted: { syncFrom(value); hexField.text = value.toUpperCase() }

  function commit() {
    internal = true
    var hex = P.hsvToHex(hue, sat, val)
    hexField.text = hex.toUpperCase()
    picker.picked(hex)
    internal = false
  }

  function pickHex(hex) {
    internal = true
    syncFrom(hex)
    hexField.text = hex.toUpperCase()
    picker.picked(hex)
    internal = false
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 10

    // ---- saturation / value square
    Item {
      id: sv
      Layout.fillWidth: true
      Layout.preferredHeight: 150

      Rectangle {
        anchors.fill: parent
        color: P.hsvToHex(picker.hue, 1, 1)
        border.width: 1
        border.color: Util.alpha(Commons.Color.menu.border, 0.6)
      }
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "#ffffffff" }
          GradientStop { position: 1.0; color: "#00ffffff" }
        }
      }
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0.0; color: "#00000000" }
          GradientStop { position: 1.0; color: "#ff000000" }
        }
      }
      Rectangle {
        x: picker.sat * sv.width - width / 2
        y: (1 - picker.val) * sv.height - height / 2
        width: 14; height: 14; radius: 7
        color: "transparent"
        border.width: 2
        border.color: picker.val > 0.6 && picker.sat < 0.5 ? "#000000" : "#ffffff"
        Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: picker.value }
      }
      MouseArea {
        anchors.fill: parent
        enabled: picker.editable
        preventStealing: true
        function set(m) {
          picker.sat = Math.max(0, Math.min(1, m.x / width))
          picker.val = 1 - Math.max(0, Math.min(1, m.y / height))
          picker.commit()
        }
        onPressed: function(m) { set(m) }
        onPositionChanged: function(m) { if (pressed) set(m) }
      }
    }

    // ---- hue strip
    Item {
      id: hueStrip
      Layout.fillWidth: true
      Layout.preferredHeight: 16

      Rectangle {
        anchors.fill: parent
        border.width: 1
        border.color: Util.alpha(Commons.Color.menu.border, 0.6)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.000; color: "#ff0000" }
          GradientStop { position: 0.167; color: "#ffff00" }
          GradientStop { position: 0.333; color: "#00ff00" }
          GradientStop { position: 0.500; color: "#00ffff" }
          GradientStop { position: 0.667; color: "#0000ff" }
          GradientStop { position: 0.833; color: "#ff00ff" }
          GradientStop { position: 1.000; color: "#ff0000" }
        }
      }
      Rectangle {
        x: picker.hue * hueStrip.width - width / 2
        width: 6; height: parent.height + 4; y: -2
        color: "transparent"
        border.width: 2
        border.color: "#ffffff"
      }
      MouseArea {
        anchors.fill: parent
        enabled: picker.editable
        preventStealing: true
        function set(m) {
          picker.hue = Math.max(0, Math.min(0.9999, m.x / width))
          picker.commit()
        }
        onPressed: function(m) { set(m) }
        onPositionChanged: function(m) { if (pressed) set(m) }
      }
    }

    // ---- hex field + swatch
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        Layout.preferredWidth: 44
        Layout.preferredHeight: 30
        color: picker.value
        border.width: 1
        border.color: Util.alpha(Commons.Color.menu.border, 0.8)
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        color: "transparent"
        border.width: 1
        border.color: hexField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)

        Text {
          id: hash
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "HEX"
          color: Commons.Color.muted
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 1
        }
        TextInput {
          id: hexField
          anchors.left: hash.right
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          color: Commons.Color.menu.text
          selectionColor: Commons.Color.accent
          selectedTextColor: Commons.Color.background
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body + 1
          maximumLength: 9
          readOnly: !picker.editable
          inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhUppercaseOnly
          onTextEdited: {
            var t = text.trim()
            if (t.charAt(0) !== "#") t = "#" + t
            if (P.isHex(t)) picker.pickHex(t.toLowerCase())
          }
        }
      }
    }

    // ---- swatch chart
    Text {
      visible: picker.themeSwatches.length > 0
      text: "OMARCHY THEME"
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      font.letterSpacing: 1.5
    }
    Flow {
      Layout.fillWidth: true
      visible: picker.themeSwatches.length > 0
      spacing: 4
      Repeater {
        model: picker.themeSwatches
        Rectangle {
          width: 22; height: 22
          color: modelData
          border.width: modelData.toLowerCase() === picker.value.toLowerCase() ? 2 : 1
          border.color: modelData.toLowerCase() === picker.value.toLowerCase() ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.5)
          MouseArea { anchors.fill: parent; enabled: picker.editable; onClicked: picker.pickHex(modelData.toLowerCase()) }
        }
      }
    }

    Text {
      text: "CHART"
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      font.letterSpacing: 1.5
    }
    Flow {
      Layout.fillWidth: true
      spacing: 4
      Repeater {
        model: P.SWATCHES
        Rectangle {
          width: 22; height: 22
          color: modelData
          border.width: modelData.toLowerCase() === picker.value.toLowerCase() ? 2 : 1
          border.color: modelData.toLowerCase() === picker.value.toLowerCase() ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.5)
          MouseArea { anchors.fill: parent; enabled: picker.editable; onClicked: picker.pickHex(modelData) }
        }
      }
    }
  }
}

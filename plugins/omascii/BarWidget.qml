import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar button for omascii: toggles the font browser overlay.
Panel {
  id: root
  moduleName: "omacraft.omascii"

  // nf-md-alphabetical (U+F0626), same as the Style > Boot ASCII menu entry
  readonly property string glyph: String.fromCodePoint(0xF0626)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    tooltipText: "Boot ASCII"
    onPressed: function(b) {
      Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omacraft.omascii", "{}"])
    }
  }
}

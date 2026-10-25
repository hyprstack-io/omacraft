import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar button for the Agent Dock: toggles the side panel.
BarWidget {
  id: root
  moduleName: "omacraft.agentdock"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{f06a9}"
    tooltipText: "Agent Dock (Super+Alt+A)"
    onPressed: function(b) {
      if (b === Qt.LeftButton)
        Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omacraft.agentdock", "{}"])
    }
  }
}

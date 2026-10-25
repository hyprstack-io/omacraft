import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar icon for HyprCraft. The customizer itself is a React app hosted by
// bin/hyprcraft (QtWebEngine cannot run inside the shell process), so this
// widget works out where the dropdown should sit under the icon and hands
// that rectangle to the host, which pins its window there.
BarWidget {
  id: root
  moduleName: "omacraft.hyprcraft"

  readonly property string hostBin: decodeURIComponent(Qt.resolvedUrl("bin/hyprcraft").toString().replace(/^file:\/\//, ""))
  readonly property int dropdownWidth: setting("width", 1280)
  readonly property int dropdownHeight: setting("height", 840)
  readonly property bool hideOnBlur: setting("hideOnBlur", false) === true
  readonly property int gap: 8

  implicitWidth: iconButton.implicitWidth
  implicitHeight: iconButton.implicitHeight

  function clamp(value, low, high) {
    return Math.max(low, Math.min(value, high))
  }

  // Dropdown rectangle in monitor-local logical pixels, which is what
  // Hyprland's window-rule move/size expect.
  function anchorArgs() {
    var win = iconButton.QsWindow ? iconButton.QsWindow.window : null
    if (!win || !win.screen) return []

    var screen = win.screen
    var point = iconButton.mapToItem(null, 0, 0)
    var position = root.bar && root.bar.position ? root.bar.position : "top"

    // Same correction the bar uses: bottom/right bar surfaces are anchored to
    // the far edge, so their scene origin is not the monitor origin.
    if (position === "bottom")
      point.y += Math.max(0, screen.height - win.height)
    else if (position === "right")
      point.x += Math.max(0, screen.width - win.width)

    var iconW = iconButton.width
    var iconH = iconButton.height
    var w, h, x, y

    if (position === "left" || position === "right") {
      w = Math.min(dropdownWidth, screen.width - iconW - gap * 3)
      h = Math.min(dropdownHeight, screen.height - gap * 2)
      x = position === "left" ? point.x + iconW + gap : point.x - gap - w
      y = clamp(point.y + iconH / 2 - h / 2, gap, screen.height - h - gap)
    } else {
      w = Math.min(dropdownWidth, screen.width - gap * 2)
      h = Math.min(dropdownHeight, screen.height - iconH - gap * 3)
      x = clamp(point.x + iconW / 2 - w / 2, gap, screen.width - w - gap)
      y = position === "bottom" ? point.y - gap - h : point.y + iconH + gap
    }

    return [
      "--monitor", String(screen.name || ""),
      "--x", String(Math.round(x)),
      "--y", String(Math.round(y)),
      "--width", String(Math.round(w)),
      "--height", String(Math.round(h))
    ]
  }

  function send(action) {
    var args = [hostBin, action].concat(anchorArgs())
    if (hideOnBlur) args.push("--hide-on-blur")
    Quickshell.execDetached(args)
  }

  Component.onCompleted: {
    if (setting("preload", false) === true) Quickshell.execDetached([hostBin, "start"])
  }

  BarIconButton {
    id: iconButton
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "HyprCraft\nClick: open · Right click: pop out · Middle click: quit"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.send("popout")
      else if (mouseButton === Qt.MiddleButton) Quickshell.execDetached([root.hostBin, "quit"])
      else root.send("toggle")
    }
  }
}

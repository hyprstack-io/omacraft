import QtQuick
import qs.Commons
import "../LauncherStyles.js" as Styles

// A thumbnail of the screen with the launcher drawn in one of its layouts,
// in the given scheme's colors: bg (card), alt (rows/surfaces), fg (text
// lines), sel (the selected row).
Item {
  id: preview

  property string layoutId: "classic"
  property var scheme: ({ bg: "#1e1e2e", alt: "#313244", fg: "#cdd6f4", sel: "#89b4fa" })
  property color desktop: "#0b0f14"

  readonly property real r: Style.cornerRadius > 0 ? 3 : 0

  // Presets draw as their base layout, moved and resized by their options.
  readonly property var def: Styles.layout(layoutId)
  readonly property string base: Styles.baseOf(def)
  readonly property bool onRight: def.side === "right"
  // A preset's size relative to its base's default, kept inside the frame.
  function scaled(fraction, key, fallback, cap) {
    if (def[key] === "full") return cap
    return Math.min(cap, fraction * (def[key] || fallback) / fallback)
  }
  // An anchored preset's card in its corner or on its edge; otherwise where
  // its layout puts it (at).
  readonly property string anchor: def.anchor && def.anchor !== "center" ? def.anchor : ""
  function ax(frame, w, at) {
    if (anchor === "") return at
    return anchor.indexOf("left") >= 0 ? 4 : anchor.indexOf("right") >= 0 ? frame - w - 4 : (frame - w) / 2
  }
  function ay(frame, h, at) {
    if (anchor === "") return at
    return anchor.indexOf("top") >= 0 ? 4 : anchor.indexOf("bottom") >= 0 ? frame - h - 4 : (frame - h) / 2
  }

  Rectangle {
    anchors.fill: parent
    radius: preview.r * 2
    color: preview.desktop
    clip: true

    // A faint wallpaper-ish gradient so the card reads as floating.
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.lighter(preview.desktop, 1.6) }
      GradientStop { position: 1; color: preview.desktop }
    }

    // ---- classic: small card, upper middle
    Rectangle {
      visible: preview.base === "classic"
      width: parent.width * 0.3; height: parent.height * 0.62
      x: (parent.width - width) / 2; y: parent.height * 0.14
      radius: preview.r; color: preview.scheme.bg
      Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 3
        Repeater {
          model: 6
          Rectangle {
            required property int index
            width: parent.width; height: 5; radius: 1
            color: index === 1 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.22)
          }
        }
      }
    }

    // ---- sidebar: full-height drawer on the left
    Rectangle {
      visible: preview.base === "sidebar"
      readonly property real inset: preview.def.floating ? 6 : 0
      width: parent.width * (preview.def.floating ? 0.27 : 0.3)
      height: preview.def.floating ? parent.height * 0.78 : parent.height
      x: preview.onRight ? parent.width - width - inset : inset
      y: (parent.height - height) / 2
      radius: preview.def.floating ? preview.r * 2 : 0
      color: preview.scheme.bg
      Rectangle { x: 4; y: 4; width: parent.width - 8; height: 7; radius: 1; color: preview.scheme.alt }
      Column {
        x: 4; y: 15; width: parent.width - 8; spacing: 3
        Repeater {
          model: 8
          Rectangle {
            required property int index
            width: parent.width; height: 6; radius: 1
            color: index === 2 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.2)
          }
        }
      }
    }

    // ---- spotlight: wide search popup
    Rectangle {
      visible: preview.base === "spotlight"
      width: parent.width * preview.scaled(0.62, "width", 700, 0.9)
      height: parent.height * (preview.def.width && preview.def.width < 600 ? 0.4 : 0.5)
      x: preview.ax(parent.width, width, (parent.width - width) / 2)
      y: preview.ay(parent.height, height, preview.def.top === "center" ? (parent.height - height) / 2 : parent.height * (Number(preview.def.top) || 0.16))
      radius: preview.r; color: preview.scheme.bg
      Rectangle { x: 4; y: 4; width: parent.width - 8; height: 9; radius: 2; color: preview.scheme.alt }
      Column {
        x: 4; y: 17; width: parent.width - 8; spacing: 3
        Repeater {
          model: 4
          Rectangle {
            required property int index
            width: parent.width; height: 5; radius: 1
            color: index === 0 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.2)
          }
        }
      }
    }

    // ---- split: list on the left, wallpaper pane on the right
    Rectangle {
      visible: preview.base === "split"
      width: parent.width * preview.scaled(0.64, "width", 900, 0.92)
      height: parent.height * preview.scaled(0.62, "height", 540, 0.86)
      x: preview.ax(parent.width, width, (parent.width - width) / 2); y: preview.ay(parent.height, height, (parent.height - height) / 2)
      radius: preview.r; color: preview.scheme.bg
      clip: true
      Rectangle {
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: parent.width * 0.42
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.lighter(preview.scheme.sel, 1.2) }
          GradientStop { position: 1; color: preview.scheme.alt }
        }
      }
      Column {
        x: 4; y: 4; width: parent.width * 0.58 - 8; spacing: 3
        Repeater {
          model: 6
          Rectangle {
            required property int index
            width: parent.width; height: 5; radius: 1
            color: index === 1 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.2)
          }
        }
      }
    }

    // ---- launchpad: fullscreen icon grid over a dimmed backdrop
    Rectangle {
      visible: preview.base === "launchpad"
      anchors.fill: parent
      color: Util.alpha(preview.scheme.bg, 0.82)
      Rectangle {
        width: parent.width * 0.3; height: 6; radius: 3
        x: (parent.width - width) / 2; y: 6
        color: preview.scheme.alt
      }
      Grid {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 4
        columns: 6; spacing: 6
        Repeater {
          model: 18
          Rectangle {
            required property int index
            width: 9; height: 9; radius: 2
            color: index === 7 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.3)
          }
        }
      }
    }

    // ---- grid: centered card with an icon grid
    Rectangle {
      id: gridCard
      visible: preview.base === "grid"
      readonly property int cols: preview.def.columns ? Math.max(3, preview.def.columns - 1) : 4
      width: parent.width * preview.scaled(0.5, "width", 860, 0.9)
      height: parent.height * preview.scaled(0.66, "height", 600, 0.88)
      x: preview.ax(parent.width, width, (parent.width - width) / 2); y: preview.ay(parent.height, height, (parent.height - height) / 2)
      radius: preview.r; color: preview.scheme.bg
      Rectangle { x: 4; y: 4; width: parent.width - 8; height: 7; radius: 1; color: preview.scheme.alt }
      Grid {
        x: 6; y: 16; columns: gridCard.cols; spacing: 5
        Repeater {
          model: gridCard.cols * 2
          Rectangle {
            required property int index
            width: 9; height: 9; radius: 2
            color: index === 2 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.3)
          }
        }
      }
    }

    // ---- dock: icon strip along the bottom
    Rectangle {
      visible: preview.base === "dock"
      width: parent.width * 0.7; height: 17
      x: (parent.width - width) / 2
      y: preview.def.edge === "top" ? 6 : parent.height - height - 6
      radius: preview.r * 2; color: preview.scheme.bg
      Row {
        anchors.centerIn: parent; spacing: 5
        Repeater {
          model: 8
          Rectangle {
            required property int index
            width: 9; height: 9; radius: 2
            color: index === 3 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.3)
          }
        }
      }
    }

    // ---- topbar: dmenu-style strip across the top
    Rectangle {
      visible: preview.base === "topbar"
      width: parent.width; height: 12
      y: preview.def.edge === "bottom" ? parent.height - height : 0
      color: preview.scheme.bg
      Row {
        x: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 4
        Rectangle { width: 22; height: 6; radius: 1; color: preview.scheme.alt }
        Repeater {
          model: 6
          Rectangle {
            required property int index
            width: 14; height: 5; radius: 1
            color: index === 0 ? preview.scheme.sel : Util.alpha(preview.scheme.fg, 0.25)
          }
        }
      }
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "popout"

// One widget, two buttons. Each bar entry picks its role in shell.json:
//
//   { "id": "omacraft.studio", "role": "launcher" }    Omarchy menu (left: open, right: terminal)
//   { "id": "omacraft.studio", "role": "studio" }      Studio popout (left: open, right: next wallpaper,
//                                                   middle: recolor from wallpaper)
//
// The studio popout drops from the bar with the everyday controls: the
// wallpaper and its palette, the color scheme, and the bar's contrast and
// effects. "Open Studio" opens the full hub for everything else.
Panel {
  id: root
  moduleName: "omacraft.studio"
  ipcTarget: role === "studio" ? "studio.popout" : ""

  readonly property string role: String(setting("role", "launcher"))
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property string hyprskin: pluginDir + "/bin/hyprskin"
  // nf-md-palette
  readonly property string glyph: String.fromCodePoint(0xF03D8)

  // Popout state, read from `hyprskin status` and `hyprskin bar status`.
  property var status: ({})
  property var barStatus: ({})
  property string error: ""
  property string busy: ""
  readonly property var cfg: status.settings || {}
  readonly property var paletteCfg: cfg.palette || {}
  readonly property var colors: status.palette || {}
  readonly property var ui: colors.ui || {}
  readonly property var barStyle: barStatus.style || {}
  readonly property bool barStyled: barStatus.bar === "omabar16" || barStatus.bar === "hyprbar16"
  readonly property string wallpaper: String(status.current || "")
  readonly property string wallpaperName: wallpaper.substring(wallpaper.lastIndexOf("/") + 1)

  readonly property color ink: Commons.Color.popups.text
  readonly property color dim: Util.alpha(Commons.Color.popups.text, 0.6)

  readonly property var themeSwatches: [
    "background", "lighter_background", "selection", "foreground", "accent",
    "red", "orange", "yellow", "green", "cyan", "blue", "magenta"
  ]
  readonly property var roleSwatches: [
    "primary", "on_primary", "primary_container", "secondary_container", "tertiary_container",
    "surface_container", "surface_container_highest", "outline", "error"
  ]

  implicitWidth: role === "launcher" ? launcherButton.implicitWidth : iconButton.implicitWidth
  implicitHeight: role === "launcher" ? launcherButton.implicitHeight : iconButton.implicitHeight

  function summon(payload) {
    Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omacraft.studio", JSON.stringify(payload)])
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
    if (!barProc.running) barProc.running = true
  }

  // Commands run one at a time; a click while one runs waits its turn.
  property var queue: []
  function run(label, command) {
    queue = queue.concat([{ label: label, command: command }])
    pump()
  }

  function pump() {
    if (actionProc.running || queue.length === 0) return
    var next = queue[0]
    queue = queue.slice(1)
    root.busy = next.label
    root.error = ""
    actionProc.command = next.command
    actionProc.running = true
  }

  function hyprskinCommand(args) {
    return ["python3", root.hyprskin].concat(args)
  }

  // A palette option, followed by a rebuild while wallpaper colors are live.
  function setPalette(key, value) {
    var live = root.cfg.dynamicColors !== false || root.status.themeIsDynamic
    var set = ["python3", root.hyprskin, "set", "palette." + key, JSON.stringify(value)]
    if (!live) { run(key, set); return }
    run(key, ["sh", "-c", 'python3 "$0" set "$1" "$2" && python3 "$0" theme',
              root.hyprskin, "palette." + key, JSON.stringify(value)])
  }

  function setBarStyle(key, value) {
    var next = Object.assign({}, root.barStatus)
    next.style = Object.assign({}, root.barStyle)
    if (value === null) delete next.style[key]
    else next.style[key] = value
    root.barStatus = next
    run("bar", hyprskinCommand(["bar", "style", key, value === null ? "null" : JSON.stringify(value)]))
  }

  function styleNumber(key, fallback) {
    var v = Number(root.barStyle[key])
    return isFinite(v) ? v : fallback
  }

  onOpenedChanged: if (opened) { root.error = ""; refresh() }

  Process {
    id: statusProc
    command: ["python3", root.hyprskin, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.status = JSON.parse(text) } catch (e) { root.error = "Could not read Studio status" }
      }
    }
  }

  Process {
    id: barProc
    command: ["python3", root.hyprskin, "bar", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.barStatus = JSON.parse(text) } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.error = message.split("\n").pop().replace(/^hyprskin:\s*/, "")
      }
    }
    onExited: {
      root.busy = ""
      if (root.queue.length > 0) root.pump()
      else root.refresh()
    }
  }

  // ---------------------------------------------------------------- launcher

  WidgetButton {
    id: launcherButton
    visible: root.role === "launcher"
    anchors.fill: parent
    bar: root.bar
    text: ""
    fontFamily: "omarchy"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (button === Qt.RightButton) Quickshell.execDetached(["xdg-terminal-exec"])
      else if (button === Qt.MiddleButton) root.summon({ page: "overview", toggle: true })
      else root.summon({ menu: "root", toggle: true })
    }
  }

  // ------------------------------------------------------------------ studio

  BarIconButton {
    id: iconButton
    visible: root.role !== "launcher"
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    slotSize: Style.bar.statusSlot
    tooltipText: root.opened ? "" : "Studio" + (root.wallpaperName ? " · " + root.wallpaperName : "")
      + "\nClick: popout · Right click: next wallpaper · Middle click: recolor"
    onTooltipHoveredChanged: if (tooltipHovered && !statusProc.running && !root.status.current) root.refresh()
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.run("next", root.hyprskinCommand(["next"]))
      else if (mouseButton === Qt.MiddleButton) root.run("theme", root.hyprskinCommand(["theme"]))
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: iconButton
    owner: root
    bar: root.bar
    open: root.opened && root.role !== "launcher"
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(470))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "n") root.run("next", root.hyprskinCommand(["next"]))
        else if (t === "r") root.run("theme", root.hyprskinCommand(["theme"]))
        else if (t === "s") { root.close(); root.summon({ page: "overview" }) }
      }

      // Scrolls when the screen is too short for the whole popout.
      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

      Column {
        id: column
        width: flick.width
        spacing: Style.space(12)

        // ---------- Hero: the wallpaper, its name and scheme ----------
        Rectangle {
          width: parent.width
          height: Math.round(width * 0.36)
          radius: Style.cornerRadius > 0 ? Style.space(8) : 0
          color: root.colors.background || Commons.Color.popups.background
          clip: true

          Image {
            anchors.fill: parent
            visible: root.wallpaper !== ""
            source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
            sourceSize.width: 512
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
          }

          // Legibility scrim behind the caption.
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: caption.implicitHeight + Style.space(16)
            gradient: Gradient {
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 1.0; color: Util.alpha("#000000", 0.72) }
            }
          }

          Column {
            id: caption
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(10)
            spacing: Style.space(2)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.busy === "next" ? "Finding a wallpaper…"
                : (root.busy === "theme" ? "Recoloring…" : (root.wallpaperName || "No wallpaper"))
              color: "#ffffff"
              elide: Text.ElideMiddle
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: (root.status.themeIsDynamic ? "Wallpaper colors" : "Theme: " + (root.status.theme || "?"))
                + " · " + String(root.colors.scheme || root.paletteCfg.scheme || "material")
                + " · " + String(root.colors.mode || "")
              color: Util.alpha("#ffffff", 0.75)
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        // ---------- Palette ----------
        Column {
          width: parent.width
          spacing: Style.space(3)
          visible: root.colors.background !== undefined

          Row {
            width: parent.width
            Repeater {
              model: root.themeSwatches
              Rectangle {
                required property string modelData
                width: parent.width / root.themeSwatches.length
                height: Style.space(18)
                color: root.colors[modelData] || "transparent"
              }
            }
          }
          Row {
            width: parent.width
            visible: root.ui.primary !== undefined
            Repeater {
              model: root.roleSwatches
              Rectangle {
                required property string modelData
                width: parent.width / root.roleSwatches.length
                height: Style.space(8)
                color: root.ui[modelData] || "transparent"
              }
            }
          }
        }

        // ---------- Actions ----------
        Row {
          id: actions
          width: parent.width
          spacing: Style.space(6)
          readonly property real cell: (width - spacing * 2) / 3

          Button {
            width: actions.cell
            text: "Next"
            iconText: String.fromCodePoint(0xF0F27)
            tooltipText: "Random wallpaper from the auto-change source (n)"
            fontSize: Style.font.bodySmall
            foreground: root.ink
            fontFamily: Style.font.family
            bordered: true
            iconSpinning: root.busy === "next"
            onClicked: root.run("next", root.hyprskinCommand(["next"]))
          }
          Button {
            width: actions.cell
            text: "Recolor"
            iconText: root.glyph
            tooltipText: "Build and apply a theme from the current wallpaper (r)"
            fontSize: Style.font.bodySmall
            foreground: root.ink
            fontFamily: Style.font.family
            bordered: true
            iconSpinning: root.busy === "theme"
            onClicked: root.run("theme", root.hyprskinCommand(["theme"]))
          }
          Button {
            width: actions.cell
            text: "Studio"
            iconText: String.fromCodePoint(0xF0493)
            tooltipText: "Open the full Studio: wallpapers, animations, launcher and bar (s)"
            fontSize: Style.font.bodySmall
            foreground: root.ink
            fontFamily: Style.font.family
            bordered: true
            onClicked: { root.close(); root.summon({ page: "overview" }) }
          }
        }

        PanelSeparator { foreground: root.ink }

        // ---------- Colors ----------
        PanelSectionHeader { text: "COLORS FROM THE WALLPAPER"; foreground: root.ink }

        Toggle {
          width: parent.width
          label: "Theme the desktop from the wallpaper"
          checked: root.cfg.dynamicColors !== false
          foreground: root.ink
          titleSize: Style.font.bodySmall
          onClicked: root.run("dynamic", root.hyprskinCommand(["set", "dynamicColors", JSON.stringify(!(root.cfg.dynamicColors !== false))]))
        }

        LabeledGroup {
          width: parent.width
          foreground: root.ink
          label: "Scheme"
          hint: ({
            material: "Material You roles: tonal palettes from the wallpaper's key color, like matugen",
            wallbash: "The wallpaper's own main colors carry through, like wallbash",
            pywal: "ANSI colors taken almost straight from the image, like pywal",
            classic: "The original Studio palette"
          })[root.paletteCfg.scheme || "material"] || ""
          options: [
            { value: "material", label: "Material" },
            { value: "wallbash", label: "Wallbash" },
            { value: "pywal", label: "Pywal" },
            { value: "classic", label: "Classic" }
          ]
          value: root.paletteCfg.scheme || "material"
          onPicked: function(v) { root.setPalette("scheme", v) }
        }

        LabeledGroup {
          width: parent.width
          foreground: root.ink
          label: "Mode"
          options: [
            { value: "auto", label: "Auto", tooltip: "Dark or light depending on the wallpaper" },
            { value: "dark", label: "Dark" },
            { value: "light", label: "Light" }
          ]
          value: root.paletteCfg.mode || "auto"
          onPicked: function(v) { root.setPalette("mode", v) }
        }

        LabeledGroup {
          width: parent.width
          foreground: root.ink
          label: "Style"
          options: ["balanced", "vibrant", "pastel", "muted", "mono"]
          value: root.paletteCfg.style || "balanced"
          onPicked: function(v) { root.setPalette("style", v) }
        }

        LabeledGroup {
          width: parent.width
          foreground: root.ink
          label: "Contrast"
          hint: ({
            soft: "Text at 3:1 or more; the bar may sit close to the wallpaper",
            normal: "Text at 4.5:1 or more (WCAG AA); the bar stands clear of the wallpaper",
            high: "Text at 7:1 or more (WCAG AAA); the strongest separation from the wallpaper"
          })[root.paletteCfg.contrast || "normal"] || ""
          options: [
            { value: "soft", label: "Soft" },
            { value: "normal", label: "Normal" },
            { value: "high", label: "High" }
          ]
          value: root.paletteCfg.contrast || "normal"
          onPicked: function(v) {
            root.setPalette("contrast", v)
            // The bar holds its own text to the same minimum live.
            if (root.barStyled) root.setBarStyle("minContrast", ({ soft: 3, normal: 4.5, high: 7 })[v])
          }
        }

        // ---------- Bar ----------
        PanelSeparator { foreground: root.ink; visible: root.barStyled }
        PanelSectionHeader { text: "BAR"; foreground: root.ink; visible: root.barStyled }

        LabeledGroup {
          width: parent.width
          foreground: root.ink
          visible: root.barStyled
          label: "Shape"
          options: [
            { value: "arrow", label: "▶" , tooltip: "Arrow" },
            { value: "slant", label: "◢", tooltip: "Slant" },
            { value: "round", label: "●", tooltip: "Pill" },
            { value: "block", label: "■", tooltip: "Block" },
            { value: "none", label: "—", tooltip: "Plain bar, no segments" }
          ]
          value: String(root.barStyle.shape || "none")
          onPicked: function(v) { root.setBarStyle("shape", v) }
        }

        Toggle {
          visible: root.barStyled
          width: parent.width
          label: "Outline"
          description: "A hairline around each segment in a color that stands out from the wallpaper"
          checked: root.styleNumber("outline", 0) > 0
          foreground: root.ink
          titleSize: Style.font.bodySmall
          onClicked: root.setBarStyle("outline", root.styleNumber("outline", 0) > 0 ? null : 1)
        }

        StyleSlider {
          visible: root.barStyled
          width: parent.width
          bar: root.bar
          foreground: root.ink
          label: "Shadow"
          value: root.styleNumber("shadow", 0)
          maximum: 1
          step: 0.05
          unit: "%"
          onReleased: function(v) { root.setBarStyle("shadow", v > 0 ? v : null) }
        }

        StyleSlider {
          visible: root.barStyled
          width: parent.width
          bar: root.bar
          foreground: root.ink
          label: "Backdrop"
          value: root.styleNumber("backdrop", 0)
          maximum: 1
          step: 0.05
          unit: "%"
          onReleased: function(v) { root.setBarStyle("backdrop", v > 0 ? v : null) }
        }

        StyleSlider {
          visible: root.barStyled
          width: parent.width
          bar: root.bar
          foreground: root.ink
          label: "Float"
          value: root.styleNumber("float", 0)
          maximum: 24
          step: 1
          unit: "px"
          integer: true
          onReleased: function(v) { root.setBarStyle("float", v > 0 ? v : null) }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.error !== ""
          width: parent.width
          text: root.error
          color: Commons.Color.urgent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "n next wallpaper · r recolor · s open Studio · Esc close"
          color: root.ink
          opacity: 0.4
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
      }
    }
  }
}

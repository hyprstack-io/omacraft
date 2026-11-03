import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "RofiFx.js" as Fx
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// ROFIoma's popups drawn in the shell instead of rofi: the power menu in
// any of its styles, the menus made in OmaCraft, and the keybind
// cheatsheet. Every entry has HyDE's wlogout hover (HydeCard.qml) or another
// of RofiFx.js, and comes in with the entrance set for its popup. OmaCraft
// writes what to draw to popups.json; the commands stay in its scripts,
// which this runs as `<script> exec <n>`.
//
//   omarchy-shell shell summon omacraft.rofioma '{"popup":"power","toggle":true}'
//   popup: power, menu-<id> or keybinds
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  readonly property string pluginId: (manifest && manifest.id) || "omacraft.rofioma"
  readonly property string home: Quickshell.env("HOME")
  readonly property string dataPath: home + "/.config/omacraft/rofioma/popups.json"

  property bool opened: false
  property string popup: ""
  property var data: ({})
  property string filterText: ""
  // The entry the pointer or the arrow keys are on; it's the one that swells.
  property int active: 0
  // The entry asking "sure?" before it runs.
  property int confirming: -1

  // ---------------------------------------------------------------- look

  readonly property var look: data.look || ({})
  readonly property var pal: data.palette || ({})
  // The Omarchy theme live, or the colours picked in OmaCraft.
  readonly property bool themed: (look.colors || "theme") !== "custom"
  readonly property color bg: themed ? Commons.Color.background : (pal.bg || "#1e1e2e")
  readonly property color fg: themed ? Commons.Color.foreground : (pal.fg || "#cdd6f4")
  readonly property color accent: themed ? Commons.Color.accent : (pal.accent || "#cba6f7")
  readonly property color urgent: themed ? Commons.Color.urgent : (pal.urgent || "#f38ba8")
  readonly property color alt: Qt.tint(bg, Util.alpha(fg, 0.08))
  readonly property color accentFg: (0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b) > 0.55 ? "#111111" : "#ffffff"
  readonly property real opacity_: look.opacity !== undefined ? look.opacity : 0.94
  readonly property color panelBg: Util.alpha(bg, opacity_)
  readonly property real radius: look.radius !== undefined ? look.radius : 14
  readonly property real hotRadius: radius * 50 / 14
  readonly property real borderWidth: look.border !== undefined ? look.border : 2
  readonly property string font: look.font || "JetBrainsMono Nerd Font"
  // rofi sizes text in points.
  readonly property real textSize: (look.fontSize || 12) * 1.333
  readonly property string glyphFont: "JetBrainsMono Nerd Font"

  // ---------------------------------------------------------------- what's open

  readonly property bool isPower: popup === "power"
  readonly property bool isKeybinds: popup === "keybinds"
  readonly property var menu: {
    if (popup.indexOf("menu-") !== 0) return null
    var id = popup.slice(5), menus = data.menus || []
    for (var i = 0; i < menus.length; i++) if (menus[i].id === id) return menus[i]
    return null
  }
  readonly property var power: data.power || ({})
  // The layout entries are drawn in: wlogout (HyDE's bar), row, grid, list
  // or pill for the power menu; list, grid or row for a menu.
  readonly property string layout: isPower ? (power.style || "row") : menu ? (menu.layout || "list") : "list"
  // Each popup's own motion, from RofiFx.js: how it comes in, how a lit card
  // moves, and what's behind it. A menu keeps these beside its other settings.
  readonly property var fxSource: isPower ? power : menu ? menu : ({})
  readonly property string enterStyle: isKeybinds ? "fade" : fxSource.enter || (isPower ? "cascade" : "fade")
  readonly property string hoverStyle: isKeybinds ? "hyde" : fxSource.hover || "hyde"
  readonly property string backdrop: fxSource.backdrop || "dim"
  readonly property real fxSpeed: fxSource.speed || 1
  // Runs 0 to 1 as a popup opens.
  property real clock: 1
  property real beat: 0
  NumberAnimation {
    id: entrance
    target: root; property: "clock"; from: 0; to: 1
    duration: Math.max(1, Fx.duration(root.enterStyle, root.fxSpeed, root.entries.length))
  }
  SequentialAnimation on beat {
    running: root.opened && root.hoverStyle === "pulse"
    loops: Animation.Infinite
    NumberAnimation { from: 0; to: 1; duration: 620; easing.type: Easing.InOutSine }
    NumberAnimation { from: 1; to: 0; duration: 620; easing.type: Easing.InOutSine }
  }
  readonly property bool searchable: menu !== null || isKeybinds
  readonly property bool showSearch: isKeybinds || (menu !== null && menu.search !== false)

  // Every entry, numbered as its script numbers them, then the ones the
  // filter lets through.
  readonly property var allEntries: {
    var list = isPower ? (power.buttons || []) : menu ? (menu.items || []) : isKeybinds ? binds : []
    var out = []
    for (var i = 0; i < list.length; i++) {
      var e = list[i]
      out.push({ index: i, glyph: e.glyph || "", label: isKeybinds ? e.description : (e.label || ""),
                 key: e.key || "", confirm: e.confirm === true, keys: e.keys || "", movedFrom: e.movedFrom || "",
                 dispatcher: e.dispatcher || "", arg: e.arg || "" })
    }
    return out
  }
  readonly property var entries: {
    var q = filterText.toLowerCase()
    if (!q) return allEntries
    return allEntries.filter(function(e) {
      return e.label.toLowerCase().indexOf(q) >= 0 || e.keys.toLowerCase().indexOf(q) >= 0
    })
  }
  readonly property int columns: {
    var n = Math.max(1, entries.length)
    if (isKeybinds || layout === "list") return 1
    if (isPower) return layout === "grid" ? Math.min(3, n) : n
    return layout === "grid" ? Math.max(1, menu.columns || 3) : n
  }

  // ---------------------------------------------------------------- opening

  // A payload's "popup" picks what to show; "toggle" closes it when that
  // popup is already open, so one key opens and closes it.
  function open(payload) {
    var args = {}
    try { args = JSON.parse(payload || "{}") || {} } catch (e) { args = {} }
    var next = String(args.popup || "power")
    if (args.toggle === true && opened && next === popup) { dismiss(); return }
    stopEditing()
    popup = next
    filterText = ""
    active = 0
    confirming = -1
    opened = true
    dataFile.reload()
    if (isKeybinds) loadBinds()
    clock = enterStyle === "none" ? 1 : 0
    if (enterStyle !== "none") entrance.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    stopEditing()
    opened = false
    confirming = -1
  }

  // Closing from inside goes through the shell, so its open state keeps up.
  function dismiss() {
    close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function setFilter(text) {
    filterText = text
    active = 0
    confirming = -1
  }

  function move(delta) {
    if (entries.length === 0) return
    confirming = -1
    active = (active + delta + entries.length) % entries.length
    if (isKeybinds) bindList.positionViewAtIndex(active, ListView.Contain)
  }

  // Runs entry n of what's showing, asking first if it says to.
  function activate(n) {
    if (n < 0 || n >= entries.length) return
    var e = entries[n]
    active = n
    if (isKeybinds) { startEditing(n); return }
    if (e.confirm && confirming !== n) { confirming = n; return }
    var script = isPower ? "power.sh" : "menu-" + menu.id + ".sh"
    var dir = data.dir || (home + "/.config/omacraft/rofioma")
    dismiss()
    Quickshell.execDetached(["sh", dir + "/" + script, "exec", String(e.index)])
  }

  // ---------------------------------------------------------------- data

  FileView {
    id: dataFile
    path: root.dataPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.data = JSON.parse(text()) || {} } catch (e) { console.warn("rofioma: can't read " + root.dataPath + ": " + e) } }
  }

  // ---------------------------------------------------------------- keybinds

  property var binds: []
  // The cheatsheet row waiting for new keys, and what went wrong last.
  property int editing: -1
  property string editNote: ""

  Process {
    id: bindsProc
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector { onStreamFinished: root.binds = root.parseBinds(text) }
  }
  function loadBinds() { if (!bindsProc.running) bindsProc.running = true }

  // As OmaCraft lists them: modifiers in Hyprland's order, then the key;
  // binds that were moved say where from.
  function parseBinds(text) {
    var list = []
    try { list = JSON.parse(text) || [] } catch (e) { return [] }
    var mods = [[64, "SUPER"], [1, "SHIFT"], [4, "CTRL"], [8, "ALT"]]
    var from = {}, keymap = data.keymap || {}
    for (var k in keymap) from[canonical(keymap[k])] = k
    var out = []
    for (var i = 0; i < list.length; i++) {
      var b = list[i]
      if (!b.has_description || !b.description || b.mouse) continue
      var keys = []
      for (var m = 0; m < mods.length; m++) if (b.modmask & mods[m][0]) keys.push(mods[m][1])
      // Letters upper case, names (XF86AudioMute, Return) as Hyprland spells them.
      var key = String(b.key || "")
      keys.push(!key ? "code:" + b.keycode : key.length === 1 ? key.toUpperCase() : key)
      var joined = keys.join(" + ")
      out.push({ keys: joined, description: b.description, submap: b.submap || "",
                 dispatcher: b.dispatcher, arg: b.arg, movedFrom: from[canonical(joined)] || "" })
    }
    return out
  }
  function canonical(keys) {
    var order = ["SUPER", "SHIFT", "CTRL", "ALT"]
    var alias = { SUPER: "SUPER", WIN: "SUPER", META: "SUPER", MOD4: "SUPER", LOGO: "SUPER",
                  SHIFT: "SHIFT", CTRL: "CTRL", CONTROL: "CTRL", ALT: "ALT" }
    var mods = {}, key = ""
    var parts = String(keys || "").split(/[\s+]+/)
    for (var i = 0; i < parts.length; i++) {
      if (!parts[i]) continue
      var up = parts[i].toUpperCase()
      if (alias[up]) mods[alias[up]] = true
      else key = up
    }
    var out = []
    for (var j = 0; j < order.length; j++) if (mods[order[j]]) out.push(order[j])
    out.push(key)
    return out.join(" + ")
  }

  // While a row waits for its new keys, Hyprland's binds are paused (the
  // capture submap), so pressing a taken key reaches here instead of running.
  function startEditing(n) {
    editing = n
    editNote = ""
    Quickshell.execDetached(["omacraft", "keys", "capture", "on"])
  }
  function stopEditing() {
    if (editing < 0) return
    editing = -1
    Quickshell.execDetached(["omacraft", "keys", "capture", "off"])
  }
  // OmaCraft moves it (it owns the moved keys); "" puts it back.
  function moveBind(from, to) {
    moveProc.command = ["omacraft", "keys", "move", from].concat(to ? [to] : [])
    moveProc.running = true
  }
  Process {
    id: moveProc
    stderr: StdioCollector { id: moveErr }
    onExited: function(code) {
      root.editing = -1
      Quickshell.execDetached(["omacraft", "keys", "capture", "off"])
      root.editNote = code === 0 ? "" : String(moveErr.text).trim() || "OmaCraft couldn't move it."
      // Hyprland reloads with the moved keys; read them once it has.
      reloadBinds.restart()
    }
  }
  Timer { id: reloadBinds; interval: 700; onTriggered: root.loadBinds() }

  // Hyprland's name for the key pressed: letters and digits as they are,
  // the rest by name. Shifted symbols bind as their unshifted key.
  function keyName(event) {
    var k = event.key
    if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
    if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
    if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
    var named = {}
    named[Qt.Key_Return] = "RETURN"; named[Qt.Key_Enter] = "RETURN"; named[Qt.Key_Space] = "SPACE"
    named[Qt.Key_Tab] = "TAB"; named[Qt.Key_Backtab] = "TAB"; named[Qt.Key_Backspace] = "BACKSPACE"
    named[Qt.Key_Delete] = "DELETE"; named[Qt.Key_Insert] = "INSERT"; named[Qt.Key_Home] = "HOME"; named[Qt.Key_End] = "END"
    named[Qt.Key_PageUp] = "PAGE_UP"; named[Qt.Key_PageDown] = "PAGE_DOWN"; named[Qt.Key_Print] = "PRINT"
    named[Qt.Key_Left] = "LEFT"; named[Qt.Key_Right] = "RIGHT"; named[Qt.Key_Up] = "UP"; named[Qt.Key_Down] = "DOWN"
    named[Qt.Key_Comma] = "COMMA"; named[Qt.Key_Less] = "COMMA"; named[Qt.Key_Period] = "PERIOD"; named[Qt.Key_Greater] = "PERIOD"
    named[Qt.Key_Slash] = "SLASH"; named[Qt.Key_Question] = "SLASH"; named[Qt.Key_Minus] = "MINUS"; named[Qt.Key_Underscore] = "MINUS"
    named[Qt.Key_Equal] = "EQUAL"; named[Qt.Key_Plus] = "EQUAL"; named[Qt.Key_Semicolon] = "SEMICOLON"; named[Qt.Key_Colon] = "SEMICOLON"
    named[Qt.Key_Apostrophe] = "APOSTROPHE"; named[Qt.Key_QuoteDbl] = "APOSTROPHE"; named[Qt.Key_QuoteLeft] = "GRAVE"
    named[Qt.Key_AsciiTilde] = "GRAVE"; named[Qt.Key_BracketLeft] = "BRACKETLEFT"; named[Qt.Key_BraceLeft] = "BRACKETLEFT"
    named[Qt.Key_BracketRight] = "BRACKETRIGHT"; named[Qt.Key_BraceRight] = "BRACKETRIGHT"
    named[Qt.Key_Backslash] = "BACKSLASH"; named[Qt.Key_Bar] = "BACKSLASH"
    named[Qt.Key_Exclam] = "1"; named[Qt.Key_At] = "2"; named[Qt.Key_NumberSign] = "3"; named[Qt.Key_Dollar] = "4"
    named[Qt.Key_Percent] = "5"; named[Qt.Key_AsciiCircum] = "6"; named[Qt.Key_Ampersand] = "7"; named[Qt.Key_Asterisk] = "8"
    named[Qt.Key_ParenLeft] = "9"; named[Qt.Key_ParenRight] = "0"
    named[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume"; named[Qt.Key_VolumeDown] = "XF86AudioLowerVolume"
    named[Qt.Key_VolumeMute] = "XF86AudioMute"; named[Qt.Key_MediaPlay] = "XF86AudioPlay"; named[Qt.Key_MediaNext] = "XF86AudioNext"
    named[Qt.Key_MediaPrevious] = "XF86AudioPrev"; named[Qt.Key_MonBrightnessUp] = "XF86MonBrightnessUp"
    named[Qt.Key_MonBrightnessDown] = "XF86MonBrightnessDown"
    return named[k] || ""
  }
  function isModifier(k) {
    return k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_Meta
        || k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_AltGr || k === Qt.Key_CapsLock
  }
  function comboOf(event) {
    var name = keyName(event)
    if (!name) return ""
    var keys = []
    if (event.modifiers & Qt.MetaModifier) keys.push("SUPER")
    if (event.modifiers & Qt.ShiftModifier) keys.push("SHIFT")
    if (event.modifiers & Qt.ControlModifier) keys.push("CTRL")
    if (event.modifiers & Qt.AltModifier) keys.push("ALT")
    keys.push(name)
    return keys.join(" + ")
  }

  // ---------------------------------------------------------------- keys

  function handleKey(event) {
    var k = event.key
    // A cheatsheet row waiting for its new keys takes the next combo.
    if (isKeybinds && editing >= 0) {
      if (isModifier(k)) return
      var row = entries[editing]
      if (k === Qt.Key_Escape && !event.modifiers) { stopEditing(); return }
      if (k === Qt.Key_Backspace && !event.modifiers) {
        if (row && row.movedFrom) moveBind(row.keys, "")
        else stopEditing()
        return
      }
      var combo = comboOf(event)
      if (!combo) { editNote = "That key has no name Hyprland binds by."; return }
      if (row) moveBind(row.keys, combo)
      return
    }
    if (k === Qt.Key_Escape) {
      if (confirming >= 0) confirming = -1
      else if (filterText) setFilter("")
      else dismiss()
      return
    }
    if (confirming >= 0) {
      if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Y) activate(confirming)
      else if (k === Qt.Key_N) confirming = -1
      return
    }
    if (k === Qt.Key_Return || k === Qt.Key_Enter) { activate(active); return }
    var across = layout === "list" || isKeybinds ? 0 : 1
    if (k === Qt.Key_Left && across) { move(-1); return }
    if (k === Qt.Key_Right && across) { move(1); return }
    if (k === Qt.Key_Up) { move(-(columns > 1 && layout === "grid" ? columns : 1)); return }
    if (k === Qt.Key_Down) { move(columns > 1 && layout === "grid" ? columns : 1); return }
    if (k === Qt.Key_Tab) { move(1); return }
    if (k === Qt.Key_Backtab) { move(-1); return }
    if (searchable && k === Qt.Key_Backspace) { setFilter(filterText.slice(0, -1)); return }
    var ch = event.text
    if (!ch || ch.length !== 1 || ch.charCodeAt(0) < 32 || ch.charCodeAt(0) === 127) return
    // The power menu has no search: a button's letter picks it, as in rofi.
    if (isPower) {
      for (var i = 0; i < entries.length; i++)
        if (entries[i].key && entries[i].key.toLowerCase() === ch.toLowerCase()) { activate(i); return }
      return
    }
    setFilter(filterText + ch)
  }

  // ---------------------------------------------------------------- drawing

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omacraft-rofioma"

    // The power menu dims the screen; the others float over it.
    FxBackdrop {
      anchors.fill: parent
      style: root.backdrop
      running: root.opened
      accent: root.accent
      second: root.urgent
      dim: root.isPower ? (root.power.dim !== undefined ? root.power.dim : 0.55) : 0.25
      opacity: Fx.clamp(root.clock * 3)
    }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) { root.handleKey(event); event.accepted = true }
    }

    // ------------------------------------------------ HyDE's bar (wlogout)
    // One bar of tall cards across the screen, margins 28% of its height,
    // 23% for the active card, which also swells its icon from 20% to 40%
    // of its width and rounds off.
    Item {
      id: barView
      anchors.fill: parent
      visible: root.isPower && root.layout === "wlogout"
      readonly property real mgn: height * 0.28
      readonly property real hvr: height * 0.23
      readonly property real cardWidth: (width - 2 * mgn) / Math.max(1, root.entries.length)
      readonly property real iconScale: (root.power.glyphSize || 44) / 44
      readonly property real ends: root.radius * 80 / 14

      Repeater {
        model: barView.visible ? root.entries : []
        delegate: Rectangle {
          id: barCard
          required property var modelData
          required property int index
          readonly property bool hot: root.active === index
          readonly property bool first: index === 0
          readonly property bool last: index === root.entries.length - 1
          property real t: 0
          NumberAnimation {
            id: barSwell
            target: barCard; property: "t"; from: 0; to: 1
            duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.55, 0.0, 0.28, 1.682, 1, 1]
          }
          onHotChanged: { barSwell.stop(); if (hot) barSwell.start(); else t = 0 }
          readonly property var enter: Fx.enter(root.enterStyle, root.clock, index, root.entries.length, barCard.width, root.entries.length)
          opacity: enter.opacity
          scale: enter.scale
          rotation: enter.rotation
          transform: [
            Translate { x: barCard.enter.x; y: barCard.enter.y },
            Rotation { origin.x: barCard.width / 2; origin.y: barCard.height / 2; axis { x: 0; y: 1; z: 0 } angle: barCard.enter.flip }
          ]
          readonly property real margin: barView.mgn + (barView.hvr - barView.mgn) * t
          x: barView.mgn + index * barView.cardWidth
          y: margin
          width: barView.cardWidth
          height: barView.height - 2 * margin
          z: hot ? 1 : 0
          topLeftRadius: (first ? barView.ends : 0) * (1 - t) + root.hotRadius * t
          bottomLeftRadius: topLeftRadius
          topRightRadius: (last ? barView.ends : 0) * (1 - t) + root.hotRadius * t
          bottomRightRadius: topRightRadius
          color: hot ? root.accent : root.panelBg

          Text {
            anchors.centerIn: parent
            text: barCard.modelData.glyph
            color: barCard.hot ? root.accentFg : root.fg
            font.family: root.glyphFont
            font.pixelSize: Math.max(6, barCard.width * barView.iconScale * (0.2 + 0.2 * barCard.t))
          }
          Text {
            visible: root.power.labels !== false
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: height
            text: root.confirming === barCard.index ? "Sure?  Enter · Esc" : barCard.modelData.label
            color: barCard.hot ? root.accentFg : root.fg
            font.family: root.font
            font.pixelSize: Math.max(10, barView.height * 0.02)
            font.bold: root.confirming === barCard.index
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) { root.active = barCard.index; if (root.confirming !== barCard.index) root.confirming = -1 }
            onClicked: root.activate(barCard.index)
          }
        }
      }
    }

    // ------------------------------------------------ cards in a panel
    // The power menu's row, grid, list and pill, and the menus, sized as
    // their rofi themes size them.
    Rectangle {
      id: card
      visible: !barView.visible && !root.isKeybinds && (root.isPower || root.menu !== null)
      anchors.centerIn: parent
      // With the screen dimmed the power cards float on it; otherwise
      // they sit in a panel, as in rofi.
      readonly property bool framed: !root.isPower || (root.power.dim !== undefined ? root.power.dim : 0.55) <= 0.001
      readonly property real pad: 18
      width: Math.max(content.width, root.menu ? menuWidth : 0) + pad * 2
      height: content.height + pad * 2 + (search.visible ? search.height + 12 : 0)
      readonly property real menuWidth: root.menu ? (root.menu.width || (root.layout === "list" ? 420 : 640)) : 0
      radius: root.radius
      color: framed ? root.panelBg : "transparent"
      border.width: framed ? root.borderWidth : 0
      border.color: root.accent
      opacity: Fx.clamp(root.clock * 4)
      MouseArea { anchors.fill: parent }

      SearchLine {
        id: search
        visible: root.showSearch && !root.isKeybinds
        x: card.pad; y: card.pad
        width: card.width - card.pad * 2
      }

      Grid {
        id: content
        x: (card.width - width) / 2
        y: card.pad + (search.visible ? search.height + 12 : 0)
        columns: root.columns
        readonly property bool list: root.layout === "list"
        readonly property bool pill: root.isPower && root.layout === "pill"
        spacing: list ? 4 : root.isPower ? (root.power.spacing !== undefined ? root.power.spacing : 14) : 8
        // Cells: the power menu's size setting, a menu's width shared out.
        readonly property real size: root.isPower ? (root.power.size || 150) : 0
        readonly property real cellWidth: list ? (root.isPower ? 320 : card.menuWidth)
                                        : root.isPower ? (pill ? size * 0.5 : size)
                                        : (card.menuWidth - (root.columns - 1) * spacing) / Math.max(1, root.columns)
        readonly property real cellHeight: list ? root.textSize * 1.4 + 20
                                         : root.isPower ? (pill ? size * 0.5 : root.layout === "row" ? size * 1.15 : size)
                                         : root.textSize * 3.2 + 34
        readonly property real glyph: root.isPower
          ? (root.power.glyphSize || 44) * 1.333 * (pill ? 0.6 : list ? 0.45 : 1)
          : root.textSize * (list ? 1.1 : 2)

        Repeater {
          model: card.visible ? root.entries : []
          delegate: HydeCard {
            required property var modelData
            required property int index
            width: content.cellWidth
            height: content.cellHeight
            shape: content.list ? "list" : "card"
            glyph: modelData.glyph
            label: modelData.label
            showLabel: content.list || (!content.pill && (!root.isPower || root.power.labels !== false))
            hot: root.active === index
            asking: root.confirming === index
            radius: content.pill ? Math.min(width, height) / 2 : content.list ? root.radius * 0.6 : root.radius
            hotRadius: content.pill ? Math.min(width, height) / 2 : content.list ? root.radius : root.hotRadius
            // Cards swell a tenth each way; list rows mostly sideways.
            growX: content.list ? 6 : width * 0.1
            growY: content.list ? 3 : height * 0.1
            glyphSize: content.glyph
            glyphGain: content.list ? 0.25 : 0.35
            textSize: root.textSize
            fontFamily: root.font
            glyphFamily: root.glyphFont
            restColor: content.list ? "transparent" : root.alt
            hotColor: root.accent
            textColor: root.fg
            hotTextColor: root.accentFg
            hoverStyle: root.hoverStyle
            beat: root.beat
            enter: Fx.enter(root.enterStyle, root.clock, index, root.entries.length, Math.max(width, 60), root.columns)
            onEntered: { root.active = index; if (root.confirming !== index) root.confirming = -1 }
            onClicked: root.activate(index)
          }
        }
      }

      Text {
        visible: root.entries.length === 0
        anchors.centerIn: parent
        text: root.filterText ? "Nothing matches “" + root.filterText + "”" : "Nothing here yet. Add some in OmaCraft › ROFIoma."
        color: root.fg
        opacity: 0.7
        font.family: root.font
        font.pixelSize: root.textSize
      }
    }

    // ------------------------------------------------ the cheatsheet
    // Every described bind; click one (or Enter) and press its new keys.
    Rectangle {
      id: sheet
      visible: root.isKeybinds
      anchors.centerIn: parent
      readonly property real pad: 18
      width: Math.min(parent.width - 80, (root.data.keybinds || {}).width || 860)
      height: Math.min(parent.height - 120, 640)
      radius: root.radius
      opacity: Fx.clamp(root.clock * 2)
      color: root.panelBg
      border.width: root.borderWidth
      border.color: root.accent
      MouseArea { anchors.fill: parent }

      SearchLine {
        id: sheetSearch
        x: sheet.pad; y: sheet.pad
        width: sheet.width - sheet.pad * 2
        placeholder: "Search keybinds…   click one to move it"
      }

      ListView {
        id: bindList
        x: sheet.pad
        y: sheetSearch.y + sheetSearch.height + 12
        width: sheet.width - sheet.pad * 2
        height: sheet.height - y - sheet.pad - noteLine.height
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: sheet.visible ? root.entries : []
        delegate: Item {
          id: bindRow
          required property var modelData
          required property int index
          readonly property bool editingThis: root.editing === index
          // The row under the pointer or the arrows, while none is being edited.
          readonly property bool lit: root.active === index && root.editing < 0
          width: bindList.width
          height: root.textSize * 1.4 + 18

          HydeCard {
            anchors.fill: parent
            shape: "list"
            glyph: ""
            label: ""
            hot: bindRow.lit || bindRow.editingThis
            radius: root.radius * 0.6
            hotRadius: root.radius
            growX: 6
            growY: 2
            restColor: "transparent"
            hotColor: bindRow.editingThis ? Util.alpha(root.accent, 0.22) : root.accent
            onEntered: if (root.editing < 0) root.active = bindRow.index
            onClicked: root.activate(bindRow.index)
          }
          // Above the swelling highlight, so the active row stays readable.
          Row {
            z: 3
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            spacing: 16
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              // One column for every row's keys, so the names line up.
              width: Math.min(bindList.width * 0.42, 330)
              height: keysText.implicitHeight + 8
              radius: 6
              color: bindRow.editingThis ? root.accent : bindRow.lit ? Util.alpha(root.accentFg, 0.12) : Util.alpha(root.fg, 0.07)
              border.width: bindRow.editingThis ? 0 : 1
              border.color: bindRow.lit ? Util.alpha(root.accentFg, 0.2) : Util.alpha(root.fg, 0.12)
              Text {
                id: keysText
                anchors.centerIn: parent
                width: parent.width - 14
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                text: bindRow.editingThis ? "Press the new keys…" : bindRow.modelData.keys
                color: bindRow.editingThis || bindRow.lit ? root.accentFg : root.accent
                font.family: "monospace"
                font.pixelSize: root.textSize * 0.92
                font.bold: true
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: bindRow.editingThis
                    ? (bindRow.modelData.movedFrom ? "Esc cancels · Backspace puts it back on " + bindRow.modelData.movedFrom : "Esc cancels")
                    : bindRow.modelData.label
              color: bindRow.lit ? root.accentFg : root.fg
              font.family: root.font
              font.pixelSize: root.textSize
            }
            Text {
              visible: !bindRow.editingThis && bindRow.modelData.movedFrom !== ""
              anchors.verticalCenter: parent.verticalCenter
              text: "moved from " + bindRow.modelData.movedFrom
              color: bindRow.lit ? root.accentFg : root.fg
              opacity: 0.55
              font.family: root.font
              font.pixelSize: root.textSize * 0.8
              font.italic: true
            }
          }
        }
      }

      Text {
        id: noteLine
        x: sheet.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: sheet.pad * 0.6
        width: sheet.width - sheet.pad * 2
        height: root.editNote ? implicitHeight + 4 : 0
        visible: root.editNote !== ""
        text: root.editNote
        wrapMode: Text.Wrap
        color: root.urgent
        font.family: root.font
        font.pixelSize: root.textSize * 0.9
      }
    }
  }

  // What's typed, as rofi's search line shows it.
  component SearchLine: Rectangle {
    property string placeholder: (root.menu && root.menu.prompt ? root.menu.prompt + "  " : "") + "Search…"
    height: root.textSize * 1.4 + 18
    radius: root.radius * 0.6
    color: Util.alpha(root.fg, 0.06)
    Text {
      anchors.verticalCenter: parent.verticalCenter
      x: 14
      width: parent.width - 28
      elide: Text.ElideRight
      text: root.filterText || parent.placeholder
      color: root.fg
      opacity: root.filterText ? 1 : 0.5
      font.family: root.font
      font.pixelSize: root.textSize
    }
  }

  IpcHandler {
    target: "rofioma"
    function open(popup: string): void { root.open(JSON.stringify({ popup: popup })) }
    function toggle(popup: string): void { root.open(JSON.stringify({ popup: popup, toggle: true })) }
    function close(): void { root.dismiss() }
  }
}

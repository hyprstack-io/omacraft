import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "components"
import "data/Presets.js" as P

// The omabar16 bar customizer, as Studio's "Bar" pages. This is the state and
// every mutation; the pages in components/ and the frame in ../hub draw it.
//
// Every edit is applied to the live bar (debounced) by merging into
// ~/.config/omarchy/shell.json, which also makes omabar16 the active bar
// (scripts/apply.sh). Revert restores what the bar looked like when the
// session began: the first time a Bar page was shown since Studio opened.
Item {
  id: root

  signal pageRequested(string tab)

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")

  property bool opened: false
  // True once this session has read shell.json; nothing is written before that.
  property bool loaded: false
  // The active bar plugin now ("" = stock omarchy.bar) and when the session
  // began. Applying any change makes omabar16 the active bar.
  property string activeBarId: ""
  property string sessionBarId: ""
  property string tab: "modules"
  property string selectedPart: "bg"
  property string status: "Ready"
  property bool pendingApply: false
  property bool awaitingSnapshot: false

  property var cfg: emptyCfg()
  property var snapshot: null
  property var undoStack: []
  property var redoStack: []
  readonly property bool canUndo: undoStack.length > 0
  readonly property bool canRedo: redoStack.length > 0
  property var catalog: []
  property var themeColors: ({})
  property var userThemes: []

  // ------------------------------------------------------------ derived

  function hex(c) {
    function h(v) {
      var s = Math.round(v * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  readonly property var defaults: ({
    background: hex(Commons.Color.bar.background),
    foreground: hex(Commons.Color.bar.text),
    accent: hex(Commons.Color.accent)
  })
  readonly property var res: P.resolve(cfg.style, themeColors, defaults)
  readonly property var allThemes: P.THEMES.concat(P.JAKOOLIT, P.HANCORE, P.BASE16, userThemes)
  readonly property string activeThemeId: {
    var cur = JSON.stringify(cfg.style || {})
    for (var i = 0; i < allThemes.length; i++)
      if (JSON.stringify(allThemes[i].style) === cur) return allThemes[i].id
    return ""
  }
  readonly property var themeSwatches: {
    var t = themeColors, out = [], keys = ["accent", "foreground", "background", "color1", "color2", "color3", "color4", "color5", "color6",
      "red", "green", "yellow", "blue", "magenta", "cyan", "orange", "color9", "color10", "color11", "color12", "color13", "color14"]
    for (var i = 0; i < keys.length; i++) {
      var v = t[keys[i]]
      if (v && out.indexOf(v) === -1) out.push(v)
    }
    return out
  }
  readonly property var availableModules: {
    var inBar = P.idsIn(cfg), out = []
    for (var i = 0; i < catalog.length; i++) {
      var c = catalog[i], multi = c.barWidget && c.barWidget.allowMultiple === true
      if (multi || inBar.indexOf(c.id) === -1) out.push(c)
    }
    return out
  }
  readonly property var parts: {
    var out = [
      { id: "bg", label: "Bar background", group: "BAR" },
      { id: "fg", label: "Text & icons", group: "BAR" },
      { id: "accent", label: "Accent", group: "BAR" },
      { id: "outlineColor", label: "Outline", group: "BAR" },
      { id: "hoverColor", label: "Hover", group: "BAR" },
      { id: "region:left", label: "Left section", group: "SECTIONS" },
      { id: "region:center", label: "Center section", group: "SECTIONS" },
      { id: "region:right", label: "Right section", group: "SECTIONS" }
    ]
    for (var i = 0; i < res.palette.length && i < 8; i++)
      out.push({ id: "pal:" + i, label: "Palette " + (i + 1), group: "PALETTE" })
    var lanes = ["left", "center", "right"], seen = {}
    for (var l = 0; l < lanes.length; l++) {
      var arr = P.laneOf(cfg, lanes[l])
      for (var j = 0; j < arr.length; j++) {
        if (seen[arr[j].id]) continue
        seen[arr[j].id] = true
        out.push({ id: "module:" + arr[j].id, label: moduleLabel(arr[j].id), group: "MODULES" })
      }
    }
    return out
  }

  function moduleLabel(id) {
    for (var i = 0; i < catalog.length; i++)
      if (catalog[i].id === id) return (catalog[i].barWidget && catalog[i].barWidget.displayName) || catalog[i].name || P.shortName(id)
    return P.shortName(id)
  }

  function emptyCfg() {
    return { position: "top", transparent: false, centerAnchor: "omarchy.clock", layout: { left: [], center: [], right: [] }, style: {} }
  }

  // ------------------------------------------------------------ lifecycle

  function setTab(name) {
    if (["modules", "layout", "themes", "studio"].indexOf(String(name)) !== -1) root.tab = String(name)
    return "ok"
  }

  function selectPart(part) {
    root.selectedPart = String(part)
    return "ok"
  }

  // Payload: {"tab": "modules|layout|themes|studio", "part": "bg|module:<id>|..."}
  function open(payloadJson) {
    var want = {}
    try { want = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    root.opened = true
    root.loaded = false
    root.tab = ["modules", "layout", "themes", "studio"].indexOf(want.tab) !== -1 ? want.tab : "modules"
    if (want.part) root.selectedPart = String(want.part)
    root.status = "Ready"
    root.awaitingSnapshot = true
    root.undoStack = []
    root.redoStack = []
    shellProc.running = true
    colorsFile.reload()
    themesFile.reload()
    catalogProc.running = true
  }

  function close() { root.opened = false }

  // Scripting before a session has loaded the bar config would apply an empty
  // layout, so those calls open Studio's Bar page instead and ask to retry.
  function notReady() {
    if (root.opened) return "the bar config is still loading; run the command again"
    root.pageRequested(root.tab)
    return "opening Studio's bar customizer; run the command again"
  }

  function loadShell(text) {
    var next = emptyCfg()
    try {
      var bar = JSON.parse(text).bar || {}
      root.activeBarId = String(bar.id || "")
      next.position = bar.position || "top"
      next.transparent = bar.transparent === true
      next.centerAnchor = bar.centerAnchor === undefined ? "omarchy.clock" : bar.centerAnchor
      var lay = bar.layout || {}
      next.layout = { left: lay.left || [], center: lay.center || [], right: lay.right || [] }
      next.style = bar.style || {}
    } catch (e) {
      // A bad or partial read must never replace what is on screen, but a
      // transient one (file mid-write, process raced) is retried so the
      // preview does not stay empty until the first edit.
      if (root.readRetries < 4) {
        root.readRetries++
        root.status = "Reading config…"
        readRetry.restart()
      } else root.status = "Could not read shell.json"
      return
    }
    root.readRetries = 0
    root.cfg = next
    root.loaded = true
    if (root.awaitingSnapshot) {
      root.snapshot = P.clone(next)
      root.sessionBarId = root.activeBarId
      root.awaitingSnapshot = false
    }
  }

  // Read through a process rather than a FileView: reload() does not re-fire
  // when the file is unchanged, and the snapshot must be taken on every open.
  property int readRetries: 0
  Timer {
    id: readRetry
    interval: 250
    onTriggered: { if (!shellProc.running) shellProc.running = true }
  }

  // Installed font families for the font pickers (fc-list, read once).
  property var fontFamilies: []
  Process {
    id: fontsProc
    running: true
    command: ["fc-list", "--format", "%{family[0]}\\n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var seen = {}, out = []
        String(text || "").split("\n").forEach(function(line) {
          var f = line.trim()
          if (f !== "" && !seen[f]) { seen[f] = true; out.push(f) }
        })
        out.sort(function(a, b) { return a.toLowerCase() < b.toLowerCase() ? -1 : 1 })
        root.fontFamilies = out
      }
    }
  }

  Process {
    id: shellProc
    command: ["cat", root.home + "/.config/omarchy/shell.json"]
    stdout: StdioCollector {
      onStreamFinished: root.loadShell(text)
    }
  }

  FileView {
    id: colorsFile
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false
    onLoaded: root.themeColors = P.parseColorsToml(text())
  }

  FileView {
    id: themesFile
    path: root.home + "/.config/omarchy/omabar16/themes.json"
    printErrors: false
    onLoaded: {
      try { root.userThemes = JSON.parse(text()) } catch (e) { root.userThemes = [] }
    }
    onLoadFailed: root.userThemes = []
  }

  Process {
    id: catalogProc
    command: ["omarchy-plugin-catalog"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var all = JSON.parse(text), out = []
          for (var i = 0; i < all.length; i++)
            if (Array.isArray(all[i].kinds) && all[i].kinds.indexOf("bar-widget") !== -1) out.push(all[i])
          root.catalog = out
        } catch (e) {}
      }
    }
  }

  // ------------------------------------------------------------ applying

  Timer {
    id: applyTimer
    interval: 320
    onTriggered: root.applyNow()
  }

  Process {
    id: applyProc
    onRunningChanged: {
      if (running) return
      if (root.pendingApply) { root.pendingApply = false; root.applyNow() }
      else { root.status = "Applied"; root.activeBarId = "omabar16" }
    }
  }

  Process { id: saveProc }

  Process {
    id: exportProc
    stdout: StdioCollector {
      onStreamFinished: root.status = "Exported to " + text.trim().replace(root.home, "~") + " (copied)"
    }
  }

  Process {
    id: importFileProc
    stdout: StdioCollector {
      onStreamFinished: root.importText(text, true)
    }
  }

  function payload() {
    return JSON.stringify({
      position: cfg.position,
      transparent: cfg.transparent,
      centerAnchor: cfg.centerAnchor,
      layout: cfg.layout,
      style: cfg.style
    })
  }

  function applyNow() {
    if (applyProc.running) { root.pendingApply = true; return }
    root.status = "Applying…"
    applyProc.command = ["bash", root.pluginDir + "scripts/apply.sh", root.payload()]
    applyProc.running = true
  }

  function commit(next) {
    if (!root.loaded) { root.status = "Still reading the bar config…"; return }
    // Rapid slider drags coalesce into one undo step (same 600ms burst).
    if (!undoBurst.running) {
      var st = undoStack.slice(-49)
      st.push(P.clone(cfg))
      undoStack = st
      redoStack = []
    }
    undoBurst.restart()
    root.cfg = next
    root.status = "Editing…"
    applyTimer.restart()
  }

  Timer { id: undoBurst; interval: 600 }

  function undo() {
    if (!canUndo) return
    var st = undoStack.slice(), prev = st.pop()
    redoStack = redoStack.concat([P.clone(cfg)])
    undoStack = st
    undoBurst.stop()
    root.cfg = prev
    root.status = "Undone"
    applyTimer.restart()
  }

  function redo() {
    if (!canRedo) return
    var st = redoStack.slice(), next = st.pop()
    undoStack = undoStack.concat([P.clone(cfg)])
    redoStack = st
    undoBurst.stop()
    root.cfg = next
    root.status = "Redone"
    applyTimer.restart()
  }

  // Per-module options live on the layout entry itself (format, size, ...).
  function findEntry(c, id) {
    var lanes = ["left", "center", "right"]
    for (var l = 0; l < lanes.length; l++) {
      var a = c.layout[lanes[l]]
      for (var i = 0; i < a.length; i++) if (a[i].id === id) return a[i]
    }
    return null
  }

  function moduleEntry(id) { return findEntry(cfg, id) }

  function setEntryOption(id, key, value) {
    var c = P.clone(cfg), e = findEntry(c, id)
    if (!e) return
    if (value === null || value === undefined || value === "") delete e[key]
    else e[key] = value
    commit(c)
  }

  function persistThemes(list) {
    root.userThemes = list
    saveProc.command = ["bash", root.pluginDir + "scripts/save-themes.sh", JSON.stringify(list)]
    saveProc.running = true
  }

  // ------------------------------------------------------------ mutations

  function newEntry(id) {
    if (id === "omarchy.spacer") return { id: id, size: 12 }
    if (id === "omarchy.clock") return { id: id, format: "dddd HH:mm", formatAlt: "d MMMM 'W'ww yyyy", verticalFormat: "HH\n—\nmm" }
    return { id: id }
  }

  function fixAnchor(c) {
    var center = P.laneOf(c, "center")
    for (var i = 0; i < center.length; i++) if (center[i].id === "omarchy.clock") { c.centerAnchor = "omarchy.clock"; return }
    c.centerAnchor = ""
  }

  function placeEntry(fromLane, fromIndex, moduleId, toLane, toIndex) {
    var c = P.clone(cfg), entry
    if (fromLane === "tray") entry = newEntry(moduleId)
    else {
      entry = c.layout[fromLane].splice(fromIndex, 1)[0]
      if (fromLane === toLane && toIndex > fromIndex) toIndex--
    }
    var arr = c.layout[toLane]
    arr.splice(Math.max(0, Math.min(toIndex, arr.length)), 0, entry)
    fixAnchor(c)
    commit(c)
  }

  function removeEntry(lane, index) {
    var c = P.clone(cfg)
    c.layout[lane].splice(index, 1)
    fixAnchor(c)
    commit(c)
  }

  function setPosition(p) {
    var c = P.clone(cfg)
    c.position = p
    commit(c)
  }

  function setTransparent(v) {
    var c = P.clone(cfg)
    c.transparent = v
    commit(c)
  }

  function knownIds() {
    var out = []
    for (var i = 0; i < catalog.length; i++) out.push(catalog[i].id)
    return out
  }

  function applyLayoutPreset(preset) {
    var known = knownIds(), c = P.clone(cfg), lanes = ["left", "center", "right"]
    var extras = [], present = []
    // Widgets from other plugins follow the user into every layout.
    for (var e = 0; e < lanes.length; e++) {
      var cur = P.laneOf(cfg, lanes[e])
      for (var x = 0; x < cur.length; x++) if (cur[x].id.indexOf("omarchy.") !== 0) extras.push(cur[x])
    }
    var next = { left: [], center: [], right: [] }
    for (var l = 0; l < lanes.length; l++) {
      var src = preset.layout[lanes[l]]
      for (var i = 0; i < src.length; i++) {
        if (known.length > 0 && known.indexOf(src[i].id) === -1) continue
        // A widget already in the bar keeps its own settings (clock format,
        // custom icon, ...); the preset only decides where it goes.
        var mine = findEntry(cfg, src[i].id)
        next[lanes[l]].push(P.clone(mine || src[i]))
        present.push(src[i].id)
      }
    }
    for (var k = 0; k < extras.length; k++) if (present.indexOf(extras[k].id) === -1) next.right.push(extras[k])
    c.layout = next
    c.centerAnchor = preset.anchor
    if (preset.position) c.position = preset.position
    fixAnchor(c)
    commit(c)
  }

  function applyTheme(theme) {
    var c = P.clone(cfg)
    c.style = P.clone(theme.style)
    commit(c)
  }

  function setStyle(key, value) {
    var c = P.clone(cfg)
    if (!c.style) c.style = {}
    if (value === null || value === undefined) delete c.style[key]
    else c.style[key] = value
    if (key === "shape" && value !== "none" && c.style.solid === undefined) c.style.solid = true
    commit(c)
  }

  // ---- colour parts (studio)

  function partColor(part) {
    var r = res, s = cfg.style || {}
    if (part === "bg") return r.bg
    if (part === "fg") return r.fg || r.text
    if (part === "accent") return r.accent
    if (part === "outlineColor") return P.isHex(s.outlineColor) ? s.outlineColor : Qt.darker(r.bg, 1.6).toString()
    if (part === "hoverColor") return P.isHex(s.hoverColor) ? s.hoverColor : (r.fg || r.text)
    // A module's own text/icon and hover colours live on its layout entry.
    if (part.indexOf("moduletext:") === 0) {
      var te = findEntry(cfg, part.substr(11))
      return te && P.isHex(te.color) ? te.color : (r.fg || r.text)
    }
    if (part.indexOf("modulehover:") === 0) {
      var he = findEntry(cfg, part.substr(12))
      return he && P.isHex(he.hoverColor) ? he.hoverColor : partColor("hoverColor")
    }
    if (part.indexOf("pal:") === 0) return r.palette[parseInt(part.substr(4))] || "#888888"
    if (part.indexOf("region:") === 0) {
      var lane = part.substr(7), arr = P.laneOf(cfg, lane)
      return P.segmentBase(r, lane, 0, Math.max(1, arr.length), arr.length ? arr[0].id : "")
    }
    if (part.indexOf("module:") === 0) {
      var id = part.substr(7), lanes = ["left", "center", "right"]
      for (var l = 0; l < lanes.length; l++) {
        var a = P.laneOf(cfg, lanes[l])
        for (var i = 0; i < a.length; i++) if (a[i].id === id) return P.segmentBase(r, lanes[l], i, a.length, id)
      }
    }
    return "#888888"
  }

  function partOverridden(part) {
    var s = cfg.style || {}
    if (part === "bg" || part === "fg" || part === "accent" || part === "outlineColor" || part === "hoverColor") return P.isHex(s[part])
    if (part.indexOf("moduletext:") === 0) { var te = findEntry(cfg, part.substr(11)); return !!(te && P.isHex(te.color)) }
    if (part.indexOf("modulehover:") === 0) { var he = findEntry(cfg, part.substr(12)); return !!(he && P.isHex(he.hoverColor)) }
    if (part.indexOf("pal:") === 0) return Array.isArray(s.palette)
    if (part.indexOf("region:") === 0) return !!(s.regions && P.isHex(s.regions[part.substr(7)]))
    if (part.indexOf("module:") === 0) return !!(s.modules && P.isHex(s.modules[part.substr(7)]))
    return false
  }

  function setPartColor(part, hexValue) {
    var c = P.clone(cfg)
    if (!c.style) c.style = {}
    var s = c.style
    if (part.indexOf("moduletext:") === 0 || part.indexOf("modulehover:") === 0) {
      var e = findEntry(c, part.substr(part.indexOf(":") + 1))
      if (!e) return
      e[part.indexOf("moduletext:") === 0 ? "color" : "hoverColor"] = hexValue
      commit(c)
      return
    }
    if (part === "bg" || part === "fg" || part === "accent" || part === "outlineColor" || part === "hoverColor") s[part] = hexValue
    else if (part.indexOf("pal:") === 0) {
      var pal = Array.isArray(s.palette) && s.palette.every(P.isHex) ? s.palette : res.palette.slice()
      pal[parseInt(part.substr(4))] = hexValue
      s.palette = pal
    } else if (part.indexOf("region:") === 0) {
      s.regions = s.regions || {}
      s.regions[part.substr(7)] = hexValue
    } else if (part.indexOf("module:") === 0) {
      s.modules = s.modules || {}
      s.modules[part.substr(7)] = hexValue
    }
    if (part !== "outlineColor" && part !== "hoverColor" && (s.shape === undefined || s.shape === "none")) s.shape = "arrow"
    commit(c)
  }

  function clearPart(part) {
    var c = P.clone(cfg), s = c.style || {}
    if (part.indexOf("moduletext:") === 0 || part.indexOf("modulehover:") === 0) {
      var e = findEntry(c, part.substr(part.indexOf(":") + 1))
      if (e) delete e[part.indexOf("moduletext:") === 0 ? "color" : "hoverColor"]
      commit(c)
      return
    }
    if (part === "bg" || part === "fg" || part === "accent" || part === "outlineColor" || part === "hoverColor") delete s[part]
    else if (part.indexOf("pal:") === 0) delete s.palette
    else if (part.indexOf("region:") === 0 && s.regions) delete s.regions[part.substr(7)]
    else if (part.indexOf("module:") === 0 && s.modules) delete s.modules[part.substr(7)]
    c.style = s
    commit(c)
  }

  // ---- user themes

  function saveTheme(name) {
    var label = String(name || "").trim()
    if (label === "") return false
    var slug = label.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
    var id = "user-" + slug
    var list = userThemes.filter(function(t) { return t.id !== id })
    list.push({ id: id, label: label, desc: "Your theme", user: true, style: P.clone(cfg.style || {}) })
    persistThemes(list)
    root.status = "Saved theme " + label
    return true
  }

  // Export one theme, or every user theme when `theme` is null.
  function exportThemes(theme) {
    var list = theme ? [theme] : userThemes
    if (list.length === 0) { root.status = "Nothing to export"; return }
    var name = theme ? P.slug(theme.label) : "omabar16-themes"
    root.status = "Exporting…"
    exportProc.command = ["bash", root.pluginDir + "scripts/export-theme.sh", name || "theme", P.exportJson(list)]
    exportProc.running = true
  }

  // Export the bar's current look, whether or not it was saved as a theme.
  function exportCurrent() {
    exportThemes({ label: "My bar", desc: "Exported look", style: P.sanitizeStyle(cfg.style || {}) })
  }

  // Accepts pasted JSON or a path to an exported file. Returns true on success.
  function importText(text, fromFile) {
    var t = String(text || "").trim()
    if (t === "") return false
    if (t.charAt(0) !== "{" && t.charAt(0) !== "[") {
      if (fromFile) { root.status = "Import failed: not a theme file"; return false }
      var path = t.replace(/^~/, root.home).replace(/^file:\/\//, "")
      root.status = "Reading file…"
      importFileProc.command = ["cat", "--", path]
      importFileProc.running = true
      return true
    }
    var found = P.parseImport(t)
    if (found.length === 0) { root.status = "Import failed: no themes found"; return false }
    var list = userThemes.slice()
    for (var i = 0; i < found.length; i++) {
      var id = "user-" + (P.slug(found[i].label) || "imported")
      list = list.filter(function(x) { return x.id !== id })
      list.push({ id: id, label: found[i].label, desc: "Imported", user: true, style: found[i].style })
    }
    persistThemes(list)
    root.status = "Imported " + found.length + (found.length === 1 ? " theme" : " themes")
    return true
  }

  function deleteTheme(id) {
    persistThemes(userThemes.filter(function(t) { return t.id !== id }))
  }

  // Put back the bar that was active when the session began (layout and
  // style edits stay; only bar.id changes).
  function useBar(id) {
    if (barProc.running) return
    barProc.command = ["bash", root.pluginDir + "scripts/set-bar.sh", String(id || "")]
    barProc.running = true
  }

  Process {
    id: barProc
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.activeBarId = String(barProc.command[barProc.command.length - 1] || "")
        root.status = root.activeBarId === "omabar16" ? "Switched to the omabar16 bar" : "Switched back to your previous bar"
      } else root.status = "Could not switch the bar"
    }
  }

  function revert() {
    if (snapshot) commit(P.clone(snapshot))
  }

  function resetDefaults() {
    if (!root.loaded) return
    var c = P.clone(cfg)
    c.position = "top"
    c.transparent = false
    c.style = P.clone(P.THEMES[0].style)
    cfg = c
    applyLayoutPreset(P.LAYOUTS[0])
  }

  // Scriptable surface: omarchy-shell omabar16 <function> [args]. Handy for
  // keybindings and for testing; the UI itself calls the same mutations.
  IpcHandler {
    target: "omabar16"

    function tab(name: string): string { root.setTab(name); root.pageRequested(root.tab); return root.tab }
    // select module:omarchy.audio | bg | hoverColor ...  (shows the Studio tab)
    function select(part: string): string { root.selectPart(part); return root.selectedPart }
    // option <widget-id> <key> <json value>; "null" removes the setting.
    function option(id: string, key: string, value: string): string {
      var v = null
      try { v = JSON.parse(value) } catch (e) { v = value }
      root.setEntryOption(id, key, v)
      return JSON.stringify(root.moduleEntry(id))
    }
    function move(fromLane: string, fromIndex: int, toLane: string, toIndex: int): string {
      if (!root.loaded) return root.notReady()
      var arr = P.laneOf(root.cfg, fromLane)
      if (fromIndex < 0 || fromIndex >= arr.length) return "bad index"
      root.placeEntry(fromLane, fromIndex, arr[fromIndex].id, toLane, toIndex)
      return "ok"
    }
    function add(id: string, lane: string, index: int): string {
      if (!root.loaded) return root.notReady()
      root.placeEntry("tray", -1, id, lane, index); return "ok"
    }
    function remove(lane: string, index: int): string {
      if (!root.loaded) return root.notReady()
      root.removeEntry(lane, index); return "ok"
    }
    function theme(id: string): string {
      if (!root.loaded) return root.notReady()
      for (var i = 0; i < root.allThemes.length; i++)
        if (root.allThemes[i].id === id) { root.applyTheme(root.allThemes[i]); return "ok" }
      return "unknown theme"
    }
    function layout(id: string): string {
      if (!root.loaded) return root.notReady()
      for (var i = 0; i < P.ALL_LAYOUTS.length; i++)
        if (P.ALL_LAYOUTS[i].id === id) { root.applyLayoutPreset(P.ALL_LAYOUTS[i]); return "ok" }
      return "unknown layout"
    }
    function position(p: string): string {
      if (!root.loaded) return root.notReady()
      root.setPosition(p); return "ok"
    }
    function color(part: string, hexValue: string): string {
      if (!root.loaded) return root.notReady()
      root.setPartColor(part, hexValue); return "ok"
    }
    function revert(): string {
      if (!root.loaded) return root.notReady()
      root.revert(); return "ok"
    }
    function exportTheme(id: string): string {
      if (!root.loaded) return root.notReady()
      if (id === "") { root.exportThemes(null); return "ok" }
      for (var i = 0; i < root.allThemes.length; i++)
        if (root.allThemes[i].id === id) { root.exportThemes(root.allThemes[i]); return "ok" }
      return "unknown theme"
    }
    function importTheme(textOrPath: string): string {
      if (!root.loaded) return root.notReady()
      return root.importText(textOrPath, false) ? "ok" : "failed"
    }
    function entry(id: string, key: string, value: string): string {
      if (!root.loaded) return root.notReady()
      if (!root.moduleEntry(id)) return "not in bar"
      root.setEntryOption(id, key, value)
      return "ok"
    }
    function undo(): string {
      if (!root.loaded) return root.notReady()
      root.undo(); return "ok"
    }
    function redo(): string {
      if (!root.loaded) return root.notReady()
      root.redo(); return "ok"
    }
    function style(key: string, value: string): string {
      if (!root.loaded) return root.notReady()
      var v = value
      if (value !== "" && !isNaN(Number(value))) v = Number(value)
      else if (value === "true") v = true
      else if (value === "false") v = false
      root.setStyle(key, value === "" ? null : v)
      return "ok"
    }
    function state(): string { return root.payload() }
  }
}

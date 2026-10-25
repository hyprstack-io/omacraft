import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons

// Agent Dock: a floating dock pill on the screen edge that expands into a
// resizable side panel with one tab per AI agent. The agents are real
// terminals (foot) that bin/agentdock floats and pins over a transparent hole
// in the panel. The dock holds reorderable launchers (drag to move, drag off
// to remove, drop apps on it from the launcher) and its own settings card.
Item {
  id: root

  // Injected by the shell's panel loader.
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  // The shell's toggle()/summon() treat `opened` as expanded.
  property bool opened: false
  property bool settingsOpen: false
  property string settingsTab: "general"

  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")
  readonly property string helper: pluginDir + "bin/agentdock"
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/skll-agentdock"
  readonly property string configPath: home + "/.config/omarchy/agentdock.json"

  readonly property var defaultAgents: [
    { id: "claude", name: "Claude Code", icon: "icons/claude.svg", command: "claude", install: "", cwd: "" },
    { id: "gemini", name: "Gemini", icon: "icons/gemini.svg", command: "gemini", install: "omarchy pkg add gemini-cli", cwd: "" }
  ]
  readonly property var defaultDock: [
    { type: "cmd", name: "Terminal", glyph: "\u{f489}", command: "omarchy-launch-terminal" },
    { type: "cmd", name: "Browser", glyph: "\u{f059f}", command: "omarchy-launch-browser" },
    { type: "cmd", name: "Files", glyph: "\u{f024b}", command: "omarchy-launch-nautilus" }
  ]

  property var agents: defaultAgents
  readonly property var visibleAgents: agents.filter(function(a) { return saved.hiddenAgents.indexOf(a.id) < 0 })
  property string monitorName: ""

  // ---- settings (persisted in state.json) -------------------------------
  readonly property bool onRight: saved.position !== "left"
  readonly property int gap: Math.max(0, Math.min(48, saved.gap))
  readonly property int iconSize: Math.max(18, Math.min(56, saved.iconSize))
  readonly property real bgOpacity: Math.max(0.3, Math.min(1, saved.opacity))

  // ---- look: shapes, colours and magnification ----
  readonly property var dockShapes: ["rounded", "pill", "soft", "square", "edge"]
  readonly property var iconShapes: ["rounded", "circle", "squircle", "square", "diamond"]
  readonly property var iconPlates: ["hover", "always", "outline"]
  readonly property var dockBorders: ["subtle", "accent", "none"]
  // Named dock colours; "theme" follows Omarchy, "#rrggbb" works too.
  readonly property var dockColors: ({ midnight: "#11111b", ink: "#000000", slate: "#1e293b", ocean: "#0b3954",
                                       forest: "#12372a", plum: "#2d1b3d", wine: "#3b0d1a", amber: "#3a2800",
                                       frost: "#dfe9f5", paper: "#f2efe9" })
  readonly property var accentColors: ({ red: "#f7768e", orange: "#ff9e64", yellow: "#e0af68", green: "#9ece6a",
                                         teal: "#73daca", cyan: "#7dcfff", blue: "#7aa2f7", purple: "#bb9af7",
                                         pink: "#ff79c6", white: "#ffffff" })
  function pickColor(value, table, fallback) {
    var v = String(value || "")
    if (/^#[0-9a-fA-F]{6}$/.test(v)) return v
    return table[v] || fallback
  }
  readonly property color tint: pickColor(saved.dockColor, dockColors, Commons.Color.background)
  readonly property bool lightTint: (0.2126 * tint.r + 0.7152 * tint.g + 0.0722 * tint.b) > 0.55
  readonly property real magMax: Math.max(1.1, Math.min(2.4, Number(saved.magnifyScale) || 1.7))
  readonly property bool magnifyOn: saved.magnify && dragIndex < 0 && !incoming && menuIndex < 0
  property real magPointer: -100000   // pointer y in itemsColumn coordinates
  property real magStrength: 0        // eases to 1 while the pointer is on the dock
  Behavior on magStrength { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

  // How much an icon centred at y grows: a cosine falloff over
  // magnifyRange icons either side of the pointer, like the macOS dock.
  function magScale(y) {
    if (!magnifyOn || magStrength <= 0) return 1
    var reach = Math.max(1, Math.min(4, saved.magnifyRange)) * slot
    var d = Math.abs(y - magPointer)
    if (d >= reach) return 1
    var f = Math.cos(d / reach * Math.PI / 2)
    return 1 + (magMax - 1) * f * f * magStrength
  }

  // Scale and vertical shift of every dock entry, from the unmagnified
  // layout, so the icons never feed back into where the pointer is. Grown
  // icons push their neighbours apart and the dock grows evenly both ways.
  readonly property var magLayout: {
    var list = dockList, scales = [], extras = [], y = 0, total = 0, widest = 1
    for (var i = 0; i < list.length; i++) {
      var h = itemHeight(list[i])
      var it = list[i] && list[i].placeholder ? list[i].item : list[i]
      var icon = !!it && it.type !== "spacer" && it.type !== "divider"
      var sc = icon ? magScale(y + h / 2) : 1
      scales.push(sc)
      extras.push(h * (sc - 1))
      total += h * (sc - 1)
      widest = Math.max(widest, sc)
      y += h
    }
    var shifts = [], acc = 0
    for (var j = 0; j < extras.length; j++) {
      shifts.push(acc + extras[j] / 2 - total / 2)
      acc += extras[j]
    }
    return { scales: scales, shifts: shifts, total: total, widest: widest }
  }

  // ---- geometry (logical px, measured from the screen edge outward) ----
  readonly property int pad: 6                       // card frame around the terminal
  readonly property int slot: iconSize + 12          // one dock icon
  readonly property int dockWidth: iconSize + 20
  readonly property int headerHeight: 38
  readonly property int handleWidth: 8
  readonly property int radius: 14
  readonly property int settingsWidth: 300
  readonly property int menuWidth: 190
  readonly property int tipWidth: 180
  readonly property int minPanel: 320
  readonly property int maxPanel: Math.max(minPanel, Math.round((panel.screen ? panel.screen.width : 1600) * 0.75))
  property int panelWidth: 520

  // The surface keeps one size while collapsed, wide enough for the settings
  // card, menus and labels, so hovering or opening a card never resizes it
  // (a resize is what made the pill flicker). It is transparent and
  // click-through outside what is drawn. Only expanding widens it, and that
  // happens before the panel animates in and after it has animated out.
  readonly property int overlayWidth: Math.max(settingsWidth, menuWidth, tipWidth)
  readonly property int surfaceWidth: gap + dockWidth + gap + Math.max(expandedSurface ? panelWidth : 0, overlayWidth) + gap
  // The pill is exactly as tall as what it holds.
  readonly property int pillHeight: 6 + slot + 9 + listHeight(dockList) + 9 + slot + 6

  // ---- expand / collapse transition ----------------------------------
  property bool expandedSurface: false   // surface sized for the panel
  property real cardProgress: 0          // 0 hidden … 1 shown
  readonly property bool cardSettled: opened && cardProgress === 1 && !openAnim.running

  NumberAnimation {
    id: openAnim
    target: root; property: "cardProgress"; to: 1
    duration: 260; easing.type: Easing.OutCubic
    onFinished: root.syncWindows(false)
  }
  NumberAnimation {
    id: closeAnim
    target: root; property: "cardProgress"; to: 0
    duration: 170; easing.type: Easing.InCubic
    onFinished: if (!root.opened) root.expandedSurface = false
  }
  // One frame for the wider surface to land before the card starts moving.
  Timer { id: openKick; interval: 32; onTriggered: { closeAnim.stop(); openAnim.start() } }

  onOpenedChanged: {
    if (opened) {
      expandedSurface = true
      openKick.restart()
    } else {
      // Terminal first, so it never hangs over a card that's leaving. The
      // card turns solid at once (terminalShown drops), covering the
      // terminal until it's gone; then it animates out.
      openKick.stop()
      openAnim.stop()
      showDelay.stop()
      hideProc.running = false
      hideProc.running = true
      closeFallback.restart()
    }
  }
  Process {
    id: hideProc
    command: [root.helper, "hide", "all"]
    onExited: root.startClose()
  }
  Timer { id: closeFallback; interval: 300; onTriggered: root.startClose() }
  function startClose() {
    closeFallback.stop()
    if (!root.opened && !closeAnim.running && root.cardProgress > 0) closeAnim.start()
    else if (!root.opened && root.cardProgress === 0) root.expandedSurface = false
  }

  // Heights of dock entries: icons, spacers and dividers.
  function itemHeight(it) {
    if (it && it.placeholder) it = it.item
    if (!it) return slot
    if (it.type === "spacer") return Math.round(slot / 2)
    if (it.type === "divider") return 13
    return slot
  }
  function listHeight(list) {
    var h = 0
    for (var i = 0; i < list.length; i++) h += itemHeight(list[i])
    return h
  }

  property string activeTab: ""
  property var running: ({})
  property var installed: ({})
  property bool busy: false
  property bool fullscreen: false
  property bool stateLoaded: false
  property bool dragging: false
  property string hoverLabel: ""
  // Shared with the inline components below, which can't see ids here.
  readonly property color bg: panel.bg
  readonly property color fg: panel.fg
  readonly property color accent: panel.accent
  readonly property color line: panel.line
  readonly property Item pillItem: pillBox
  property real hoverY: 0

  // ---- dock items and drag state --------------------------------------
  readonly property var dockItems: saved.dock
  property int dragIndex: -1        // internal drag: index in dockItems
  property int dropIndex: -1        // insertion point while dragging
  property bool dragRemove: false   // internal drag left the dock
  property real dragY: 0            // pointer y in pill coordinates
  property var incoming: null       // external drag from the launcher
  property int menuIndex: -1        // context menu target
  property real menuY: 0

  // What the pill shows: the stored items with the drag applied.
  readonly property var dockList: {
    // An internal drag leaves the list alone: rebuilding the Repeater would
    // destroy the delegate holding the pointer grab and strand the drag.
    // dragShift() slides the icons into place instead.
    var list = dockItems.slice()
    if (incoming && dropIndex >= 0) {
      list.splice(Math.max(0, Math.min(list.length, dropIndex)), 0, { placeholder: true, item: incoming })
    }
    return list
  }

  // How far item i is drawn from its own slot while an internal drag
  // previews moving dragIndex to dropIndex (or off the dock).
  function dragShift(i) {
    var d = dragIndex, list = dockItems
    if (d < 0 || d >= list.length) return 0
    var t = dragRemove ? list.length - 1 : Math.max(0, Math.min(list.length - 1, dropIndex))
    var h = itemHeight(list[d])
    if (i !== d) {
      var r = i < d ? i : i - 1
      return (i > d ? -h : 0) + (r >= t ? h : 0)
    }
    var to = 0, from = 0
    for (var k = 0, r2 = 0; k < list.length; k++) {
      if (k < d) from += itemHeight(list[k])
      if (k !== d) { if (r2 < t) to += itemHeight(list[k]); r2++ }
    }
    return to - from
  }

  function clampWidth(w) { return Math.max(minPanel, Math.min(maxPanel, Math.round(w || 520))) }
  function agentById(id) {
    for (var i = 0; i < agents.length; i++) if (agents[i].id === id) return agents[i]
    return null
  }
  function iconUrl(a) {
    if (!a || !a.icon) return ""
    return a.icon.charAt(0) === "/" ? "file://" + a.icon : Qt.resolvedUrl(a.icon)
  }
  function binOf(a) { return String(a.command || "").split(" ")[0] }
  function expandHome(p) { return p.indexOf("~/") === 0 ? home + p.slice(1) : (p === "~" ? home : p) }

  function desktopEntry(id) {
    DesktopEntries.applications.values   // re-evaluate once apps are indexed
    return DesktopEntries.byId(String(id || "").replace(/\.desktop$/, ""))
  }
  function itemLabel(it) {
    if (!it) return ""
    if (it.type === "spacer") return "Spacer"
    if (it.type === "divider") return "Divider"
    if (it.type === "app") { var e = desktopEntry(it.id); return e ? e.name : it.id }
    return it.name || it.command
  }
  function itemIcon(it) {
    if (!it || it.type !== "app") return ""
    var e = desktopEntry(it.id)
    if (!e || !e.icon) return ""
    if (e.icon.charAt(0) === "/") return "file://" + e.icon
    return Quickshell.iconPath(e.icon, true)
  }
  function launchItem(it) {
    if (!it || it.type === "spacer" || it.type === "divider") return
    if (it.type === "app") Quickshell.execDetached(["sh", "-c", "exec uwsm-app -- gtk-launch \"$1\"", "sh", it.id + ".desktop"])
    else Quickshell.execDetached(["bash", "-lc", it.command])
  }
  function setDock(list) { saved.dock = list }
  function addApp(id, index) {
    id = String(id || "").replace(/\.desktop$/, "")
    if (!id) return
    var list = dockItems.slice()
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].type === "app" && list[i].id === id) {
        list.splice(i, 1)
        if (index > i) index--
      }
    }
    list.splice(index < 0 ? list.length : Math.min(index, list.length), 0, { type: "app", id: id })
    setDock(list)
  }
  // Installed apps for the settings list, filtered by `query`.
  function appResults(query) {
    var q = String(query || "").toLowerCase().trim()
    var all = DesktopEntries.applications.values
    var out = []
    for (var i = 0; i < all.length; i++) {
      var e = all[i]
      if (!e || e.noDisplay) continue
      if (q && String(e.name).toLowerCase().indexOf(q) < 0 && String(e.id).toLowerCase().indexOf(q) < 0) continue
      out.push({ id: String(e.id), name: String(e.name) })
    }
    out.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return out
  }
  function addItem(it) {
    var list = dockItems.slice()
    list.push(it)
    setDock(list)
  }
  function dockIndexOfApp(id) {
    for (var i = 0; i < dockItems.length; i++) if (dockItems[i].type === "app" && dockItems[i].id === id) return i
    return -1
  }
  function removeItem(index) {
    var list = dockItems.slice()
    list.splice(index, 1)
    setDock(list)
  }
  function moveItem(from, to) {
    var list = dockItems.slice()
    var it = list.splice(from, 1)[0]
    list.splice(Math.max(0, Math.min(list.length, to)), 0, it)
    setDock(list)
  }

  // ---- shell contract -------------------------------------------------
  function open(payloadJson) {
    var p = {}
    try { p = payloadJson ? JSON.parse(payloadJson) : {} } catch (e) {}
    if (p.tab && agentById(p.tab)) root.activeTab = p.tab
    if (p.settings === true) root.settingsOpen = true
    else root.opened = true
  }
  function close() { root.opened = false; root.settingsOpen = false }
  function toggle() { root.opened ? close() : open("") }

  onActiveTabChanged: {
    if (stateLoaded && saved.activeTab !== activeTab) saved.activeTab = activeTab
    syncWindows(false)
  }
  onGapChanged: placeDebounce.restart()
  onOnRightChanged: placeDebounce.restart()

  // ---- talking to Hyprland -------------------------------------------
  function run(args) { Quickshell.execDetached([root.helper].concat(args)) }

  // Terminal rect, local to the surface.
  function holeArgs() {
    return [String(Math.round(card.x + pad)), String(Math.round(card.y + headerHeight)),
            String(Math.round(card.width - 2 * pad)), String(Math.round(card.height - headerHeight - pad))]
  }

  // `launch` = the user asked for this agent explicitly (Start / Install
  // button or a tab click). Missing agents are never installed implicitly.
  function syncWindows(launch) {
    if (!root.opened) { run(["hide", "all"]); return }
    if (!root.cardSettled) return          // openAnim calls back when it lands
    var a = agentById(activeTab)
    if (!a || visibleAgents.indexOf(a) < 0) {
      if (visibleAgents.length) { activeTab = visibleAgents[0].id; return }
      run(["hide", "all"]); return
    }
    if (!launch && installed[binOf(a)] === false && running[a.id] !== true) { run(["hide", "all"]); return }
    // Wait a beat so the surface has its expanded size before measuring.
    pendingLaunch = a
    busy = true
    showDelay.restart()
  }
  property var pendingLaunch: null
  Timer {
    id: showDelay
    interval: 20
    onTriggered: {
      var a = root.pendingLaunch
      if (!a || !root.opened) { root.busy = false; return }
      var cwd = root.expandHome(a.cwd || saved.cwd || "")
      showProc.command = [root.helper, "show", a.id].concat(root.holeArgs()).concat([a.name, a.command, a.install || "", cwd])
      showProc.running = false
      showProc.running = true
    }
  }

  function placeActive() {
    if (!root.cardSettled) return
    run(["place", activeTab].concat(holeArgs()))
  }

  function closeAgent(id) { run(["close", id]) }
  function refreshStatus() { if (!statusProc.running) statusProc.running = true }

  Process {
    id: showProc
    onRunningChanged: if (!running) { root.busy = false; root.refreshStatus() }
  }

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.running = JSON.parse(text) } catch (e) {} }
    }
  }

  Process {
    id: installedProc
    stdout: StdioCollector {
      onStreamFinished: { try { root.installed = JSON.parse(text) } catch (e) {} }
    }
  }

  function checkInstalled() {
    var bins = []
    for (var i = 0; i < agents.length; i++) bins.push(binOf(agents[i]))
    installedProc.command = [root.helper, "installed"].concat(bins)
    installedProc.running = true
  }

  Timer { id: statusDebounce; interval: 250; onTriggered: root.refreshStatus() }
  Timer { id: placeDebounce; interval: 140; onTriggered: root.placeActive() }
  Timer { id: fullscreenDebounce; interval: 60; onTriggered: if (!fsProc.running) fsProc.running = true }
  Process {
    id: fsProc
    command: ["sh", "-c", "hyprctl activeworkspace -j | jq -r '.hasfullscreen'"]
    stdout: StdioCollector { onStreamFinished: root.fullscreen = String(text).trim() === "true" }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = event.name
      if (n === "openwindow" || n === "closewindow") statusDebounce.restart()
      if (n === "fullscreen" || n === "workspace" || n === "closewindow" || n === "focusedmon") fullscreenDebounce.restart()
      if (n === "monitoradded" || n === "monitorremoved" || n === "configreloaded") placeDebounce.restart()
    }
  }

  // ---- drops from the launcher ----------------------------------------
  // The launcher keeps the pointer grab for the whole drag, so it can't
  // deliver a Wayland drop here. It tells us over IPC instead, and we track
  // the pointer ourselves until it says the button went up.
  property real cursorX: -1
  property real cursorY: -1
  property bool finishPending: false

  function cursorOverPill() {
    var px = cursorX - pillBox.x, py = cursorY - pillBox.y
    return px >= -32 && px <= pillBox.width + 32 && py >= -slot && py <= pillBox.height + slot
  }
  // Insertion index for a pointer at pill-y `y`, measured against the items
  // that stay put (the one being dragged is taken out first).
  function indexAtPillY(y) {
    var list = dockItems.slice()
    if (dragIndex >= 0 && dragIndex < list.length) list.splice(dragIndex, 1)
    var top = pillColumn.y + itemsColumn.y
    for (var i = 0; i < list.length; i++) {
      var h = itemHeight(list[i])
      if (y < top + h / 2) return i
      top += h
    }
    return list.length
  }

  Timer {
    id: cursorPoll
    interval: 40
    repeat: true
    onTriggered: if (!cursorProc.running) cursorProc.running = true
  }
  Process {
    id: cursorProc
    command: [root.helper, "cursor"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = String(text).trim().split(" ")
        if (p.length >= 2) { root.cursorX = Number(p[0]); root.cursorY = Number(p[1]) }
        if (!root.incoming) return
        root.dropIndex = root.cursorOverPill() ? root.indexAtPillY(root.cursorY - pillBox.y) : -1
        if (root.finishPending) root.finishIncoming()
      }
    }
  }

  function beginIncoming(appId) {
    incoming = { type: "app", id: String(appId).replace(/\.desktop$/, "") }
    dropIndex = -1
    finishPending = false
    cursorPoll.start()
  }
  function endIncoming() {
    if (!incoming) return
    finishPending = true          // take one fresh pointer reading, then drop
    cursorPoll.stop()
    if (!cursorProc.running) cursorProc.running = true
  }
  function finishIncoming() {
    cursorPoll.stop()
    var it = incoming, at = dropIndex
    incoming = null; dropIndex = -1; finishPending = false
    if (it && at >= 0) addApp(it.id, at)
  }

  // ---- persisted state -------------------------------------------------
  Process {
    id: mkState
    command: ["mkdir", "-p", root.stateDir]
    running: true
    onExited: stateFile.reload()
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    printErrors: false
    // Never write before the saved values are in, or defaults clobber them.
    onAdapterUpdated: if (root.stateLoaded) writeAdapter()
    onLoaded: root.stateReady()
    onLoadFailed: function(error) {
      if (error !== FileViewError.FileNotFound) return
      root.stateReady()
      writeAdapter()
    }

    JsonAdapter {
      id: saved
      property int width: 520
      property string activeTab: ""
      property var dock: []
      property bool dockSeeded: false
      property string position: "right"
      property int gap: 10
      property int iconSize: 28
      property real opacity: 0.94
      property bool reserveCollapsed: false
      property bool reserveExpanded: true
      property var hiddenAgents: []
      property string cwd: ""
      // Look: magnification (the macOS effect), shapes and colours
      property bool magnify: false
      property real magnifyScale: 1.7
      property int magnifyRange: 2
      property string dockShape: "rounded"
      property string iconShape: "rounded"
      property string iconPlate: "hover"
      property string dockColor: "theme"
      property string accentColor: "theme"
      property string dockBorder: "subtle"
    }
  }

  function stateReady() {
    if (stateLoaded) return
    stateLoaded = true
    if (!saved.dockSeeded) { saved.dock = defaultDock; saved.dockSeeded = true }
    panelWidth = clampWidth(saved.width)
    if (agentById(saved.activeTab)) activeTab = saved.activeTab
  }

  // ---- optional user config (agents, monitor) -------------------------
  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var c = JSON.parse(text())
        if (Array.isArray(c.agents) && c.agents.length) root.agents = c.agents
        if (typeof c.monitor === "string") root.monitorName = c.monitor
      } catch (e) {
        console.warn("agentdock: can't parse " + root.configPath + ": " + e)
      }
      root.checkInstalled()
    }
    onLoadFailed: root.checkInstalled()
  }

  Component.onCompleted: {
    if (activeTab === "" && agents.length) activeTab = agents[0].id
    run(["hide", "all"])
    refreshStatus()
    if (monitorName === "" && Hyprland.focusedMonitor) monitorName = Hyprland.focusedMonitor.name
  }

  IpcHandler {
    target: "agentdock"
    function toggle(): void { root.toggle() }
    function expand(): void { root.opened = true }
    function collapse(): void { root.close() }
    function settings(): void { root.menuIndex = -1; root.settingsOpen = !root.settingsOpen }
    function tab(id: string): string {
      if (!root.agentById(id)) return "unknown"
      root.activeTab = id
      root.opened = true
      return "ok"
    }
    function width(px: int): void { root.panelWidth = root.clampWidth(px); saved.width = root.panelWidth; placeDebounce.restart() }
    function addApp(id: string): void { root.addApp(id, -1) }
    function addSpacer(): void { root.addItem({ type: "spacer" }) }
    function addDivider(): void { root.addItem({ type: "divider" }) }
    function settingsTab(tab: string): void { root.settingsTab = tab; root.settingsOpen = true }
    // OMAcraft changes saved settings through this while the dock runs, since
    // the dock only reads state.json when it loads. value is JSON.
    function set(key: string, value: string): string {
      var keys = ["position", "gap", "iconSize", "opacity", "reserveCollapsed", "reserveExpanded",
                  "hiddenAgents", "cwd", "dock", "width", "magnify", "magnifyScale", "magnifyRange",
                  "dockShape", "iconShape", "iconPlate", "dockColor", "accentColor", "dockBorder"]
      if (keys.indexOf(key) < 0) return "unknown"
      var parsed
      try { parsed = JSON.parse(value) } catch (e) { return "bad value" }
      saved[key] = parsed
      if (key === "width") root.panelWidth = root.clampWidth(parsed)
      placeDebounce.restart()
      return "ok"
    }
    function removeApp(index: int): void { root.removeItem(index) }
    function move(from: int, to: int): void { root.moveItem(from, to) }
    // Called by the launcher while one of its apps is dragged.
    function dragStart(appId: string): void { root.beginIncoming(appId) }
    function dragEnd(): void { root.endIncoming() }
    function dragCancel(): void { cursorPoll.stop(); root.incoming = null; root.dropIndex = -1 }
    function state(): string {
      return JSON.stringify({ expanded: root.opened, settings: root.settingsOpen, tab: root.activeTab,
                              width: root.panelWidth, running: root.running, dock: root.dockItems,
                              incoming: root.incoming, dropIndex: root.dropIndex })
    }
  }

  // ---- the surface -----------------------------------------------------
  PanelWindow {
    id: panel

    screen: {
      var s = Quickshell.screens
      for (var i = 0; i < s.length; i++) if (s[i].name === root.monitorName) return s[i]
      return s.length ? s[0] : null
    }

    // Full height on one edge, always: the pill is centred inside, so its
    // screen position never depends on the surface size.
    anchors {
      left: !root.onRight
      right: root.onRight
      top: true
      bottom: true
    }
    implicitWidth: root.surfaceWidth
    exclusiveZone: root.expandedSurface
      ? (saved.reserveExpanded ? root.gap + root.dockWidth + root.gap + root.panelWidth : 0)
      : (saved.reserveCollapsed ? root.gap + root.dockWidth : 0)
    color: "transparent"
    visible: !root.fullscreen
    // Overlay layer: Hyprland reserves edge space layer by layer, bottom to
    // overlay, so the bar claims its strip first and keeps its full width.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "skll-agentdock"
    WlrLayershell.keyboardFocus: root.settingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property color bg: Util.alpha(root.tint, root.bgOpacity)
    readonly property color fg: root.lightTint ? "#1b1b1f" : Commons.Color.foreground
    readonly property color accent: root.pickColor(saved.accentColor, root.accentColors, Commons.Color.accent)
    readonly property color line: Util.alpha(fg, 0.12)
    readonly property bool terminalShown: root.cardSettled && !root.busy && root.running[root.activeTab] === true

    // x for a box `o` px from the screen edge, `w` wide.
    function edgeX(o, w) { return root.onRight ? width - o - w : o }

    onWidthChanged: placeDebounce.restart()
    onHeightChanged: placeDebounce.restart()

    // Input only where something is drawn; the rest passes through.
    mask: Region {
      Region { x: pillBox.x + pillBg.x; y: pillBox.y + pillBg.y; width: pillBg.width; height: pillBg.height }
      Region {
        x: card.x; y: card.y
        width: root.cardProgress > 0.5 ? card.width : 0
        height: panel.terminalShown ? root.headerHeight : card.height
      }
      Region { x: card.x + handle.x - 3; y: card.y; width: root.cardSettled ? handle.width + 6 : 0; height: card.height }
      Region { x: settingsCard.x; y: settingsCard.y; width: root.settingsOpen ? settingsCard.width : 0; height: settingsCard.height }
      Region { x: itemMenu.x; y: itemMenu.y; width: root.menuIndex >= 0 ? itemMenu.width : 0; height: itemMenu.height }
    }

    // ================= expanded panel =================
    Item {
      id: card
      visible: root.cardProgress > 0
      x: panel.edgeX(root.gap + root.dockWidth + root.gap, root.panelWidth)
      y: root.gap
      width: root.panelWidth
      height: panel.height - 2 * root.gap

      // Slides out from behind the dock, unfolding from the dock side.
      opacity: Math.min(1, root.cardProgress * 1.4)
      transform: [
        Translate { x: (1 - root.cardProgress) * 36 * (root.onRight ? 1 : -1) },
        Scale {
          origin.x: root.onRight ? card.width : 0
          origin.y: card.height / 2
          xScale: 0.94 + 0.06 * root.cardProgress
          yScale: 0.985 + 0.015 * root.cardProgress
        }
      ]

      // Frame around the terminal hole, and a solid body when no terminal shows.
      Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: panel.terminalShown ? "transparent" : panel.bg
        Behavior on color { ColorAnimation { duration: 90 } }
        border.width: panel.terminalShown ? root.pad : 1
        border.color: panel.terminalShown ? panel.bg : panel.line
      }
      Rectangle {
        visible: panel.terminalShown
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.headerHeight
        radius: root.radius
        color: panel.bg
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: root.radius; color: panel.bg }
      }

      // Tab row
      Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: root.pad + 4; rightMargin: root.pad + 4 }
        height: root.headerHeight

        Row {
          anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 4 }
          height: parent.height - 10
          spacing: 2

          Repeater {
            model: root.visibleAgents
            delegate: Rectangle {
              id: tabItem
              required property var modelData
              readonly property bool current: modelData.id === root.activeTab
              readonly property bool live: root.running[modelData.id] === true
              height: parent.height
              width: tabRow.implicitWidth + 20
              radius: 8
              color: current ? Util.alpha(panel.fg, 0.10) : (tabMouse.containsMouse ? Util.alpha(panel.fg, 0.05) : "transparent")

              Rectangle {
                visible: tabItem.current
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 8 }
                height: 2
                color: panel.accent
              }

              Row {
                id: tabRow
                anchors.centerIn: parent
                spacing: 6
                Image {
                  anchors.verticalCenter: parent.verticalCenter
                  source: root.iconUrl(tabItem.modelData)
                  sourceSize: Qt.size(Style.font.icon, Style.font.icon)
                  width: Style.font.icon; height: Style.font.icon
                  visible: source != ""
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: tabItem.modelData.name
                  color: panel.fg
                  opacity: tabItem.current ? 1 : 0.7
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: tabItem.current
                }
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 6; height: 6; radius: 3
                  color: panel.accent
                  visible: tabItem.live
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: tabItem.live && (tabMouse.containsMouse || closeMouse.containsMouse)
                  text: "\u{f0156}"
                  color: closeMouse.containsMouse ? Commons.Color.urgent : panel.fg
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeAgent(tabItem.modelData.id)
                  }
                }
              }

              MouseArea {
                id: tabMouse
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                  if (mouse.button === Qt.MiddleButton) { root.closeAgent(tabItem.modelData.id); return }
                  if (tabItem.current) root.syncWindows(true)   // re-raise / relaunch
                  else root.activeTab = tabItem.modelData.id
                }
              }
            }
          }
        }
      }

      // Placeholder under the terminal while it launches or after it exits.
      Column {
        id: placeholder
        // Gone the moment a collapse starts; fades in once the card lands.
        visible: !panel.terminalShown && root.opened
        opacity: root.cardSettled && !(root.busy && live) ? 1 : 0
        Behavior on opacity { enabled: root.cardSettled; NumberAnimation { duration: 140 } }
        anchors.centerIn: parent
        spacing: 10
        readonly property var agent: root.agentById(root.activeTab)
        readonly property bool missing: agent !== null && root.installed[root.binOf(agent)] === false
        readonly property bool live: agent !== null && root.running[agent.id] === true

        Image {
          anchors.horizontalCenter: parent.horizontalCenter
          source: root.iconUrl(placeholder.agent)
          sourceSize: Qt.size(48, 48)
          width: 48; height: 48
          opacity: 0.85
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          color: panel.fg
          opacity: 0.75
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          text: root.visibleAgents.length === 0 ? "No agents enabled. Turn one on in the dock settings."
            : !placeholder.agent ? ""
            : root.busy ? "Starting " + placeholder.agent.name + "…"
            : placeholder.missing && placeholder.agent.install ? placeholder.agent.name + " isn't installed.\nStarting it runs: " + placeholder.agent.install
            : placeholder.missing ? "“" + root.binOf(placeholder.agent) + "” wasn't found on PATH."
            : placeholder.live ? placeholder.agent.name + " is running in the background."
            : placeholder.agent.name + " isn't running."
        }
        PillButton { host: root;
          anchors.horizontalCenter: parent.horizontalCenter
          visible: !root.busy && root.visibleAgents.length > 0 && placeholder.agent !== null && !(placeholder.missing && !placeholder.agent.install)
          label: !placeholder.agent ? ""
            : placeholder.missing ? "Install & start"
            : (placeholder.live ? "Show " : "Start ") + placeholder.agent.name
          onActivated: root.syncWindows(true)
        }
      }

      // Resize edge: the side away from the dock.
      Item {
        id: handle
        x: root.onRight ? 0 : parent.width - width
        anchors { top: parent.top; bottom: parent.bottom; topMargin: root.radius; bottomMargin: root.radius }
        width: root.handleWidth

        Rectangle {
          anchors.centerIn: parent
          width: 3; height: 40; radius: 1.5
          color: root.dragging || handleMouse.containsMouse ? panel.accent : panel.fg
          opacity: root.dragging || handleMouse.containsMouse ? 0.9 : 0.3
        }

        MouseArea {
          id: handleMouse
          anchors.fill: parent
          anchors.leftMargin: -3
          anchors.rightMargin: -3
          hoverEnabled: true
          preventStealing: true
          cursorShape: Qt.SizeHorCursor
          property real startScreenX: 0
          property int startWidth: 0
          // The surface's far edge moves as it grows; work in screen x so the
          // edge tracks the pointer.
          function screenX(mx) {
            var local = handle.mapToItem(panel.contentItem, mx, 0).x
            return root.onRight ? (panel.screen ? panel.screen.width : 0) - panel.width + local : local
          }
          onPressed: function(mouse) {
            startScreenX = screenX(mouse.x)
            startWidth = root.panelWidth
            root.dragging = true
          }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            var d = screenX(mouse.x) - startScreenX
            root.panelWidth = root.clampWidth(startWidth + (root.onRight ? -d : d))
            placeDebounce.restart()
          }
          onReleased: {
            root.dragging = false
            saved.width = root.panelWidth
            placeDebounce.restart()
          }
          onDoubleClicked: { root.panelWidth = 520; saved.width = 520; placeDebounce.restart() }
        }
      }
    }

    // ================= the dock pill =================
    Rectangle {
      id: pillBox
      x: panel.edgeX(root.gap, root.dockWidth)
      y: Math.round((panel.height - height) / 2)
      width: root.dockWidth
      height: root.pillHeight
      Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      color: "transparent"

      // Tracks the pointer for magnification. Passive, so the icons still get
      // their own hover and clicks.
      HoverHandler {
        id: pillHover
        onHoveredChanged: root.magStrength = hovered && saved.magnify ? 1 : 0
        onPointChanged: root.magPointer = point.position.y - pillColumn.y - itemsColumn.y
      }

      // The dock's body. It grows with the magnified icons: taller by what
      // they add, and wider on the side away from the screen edge.
      Rectangle {
        id: pillBg
        readonly property real grow: (root.magLayout.widest - 1) * root.iconSize
        readonly property real r: saved.dockShape === "pill" ? width / 2
          : saved.dockShape === "soft" ? 8
          : saved.dockShape === "square" ? 0
          : Math.min(root.radius + 4, width / 2)
        readonly property bool edge: saved.dockShape === "edge"
        z: -1
        x: root.onRight ? -grow : 0
        y: -root.magLayout.total / 2
        width: parent.width + grow
        height: parent.height + root.magLayout.total
        radius: edge ? 0 : r
        // "edge" rounds only the side facing the desktop, so the dock reads
        // as attached to the screen edge (best with no floating gap).
        topLeftRadius: edge ? (root.onRight ? 16 : 0) : r
        bottomLeftRadius: edge ? (root.onRight ? 16 : 0) : r
        topRightRadius: edge ? (root.onRight ? 0 : 16) : r
        bottomRightRadius: edge ? (root.onRight ? 0 : 16) : r
        color: panel.bg
        border.width: saved.dockBorder === "none" ? 0 : 1
        border.color: root.incoming && root.dropIndex >= 0 ? panel.accent
          : saved.dockBorder === "accent" ? Util.alpha(panel.accent, 0.75) : panel.line
      }

      Column {
        id: pillColumn
        anchors { top: parent.top; topMargin: 6; horizontalCenter: parent.horizontalCenter }
        spacing: 0

        DockButton { host: root;
          transform: Translate { y: -root.magLayout.total / 2 }
          glyph: root.onRight ? "\u{f0141}" : "\u{f0142}"
          glyphRotation: root.cardProgress * 180
          hint: root.opened ? "Collapse agents  (Super+Alt+A)" : "Agents  (Super+Alt+A)"
          highlighted: root.opened
          onActivated: root.toggle()
        }
        Item { width: 1; height: 4 }
        Rectangle { width: root.iconSize; height: 1; color: panel.line; anchors.horizontalCenter: parent.horizontalCenter
                    transform: Translate { y: -root.magLayout.total / 2 } }
        Item { width: 1; height: 4 }

        Column {
          id: itemsColumn
          Repeater {
            model: root.dockList
            delegate: DockItem { host: root; }
          }
        }

        Item { width: 1; height: 4 }
        Rectangle { width: root.iconSize; height: 1; color: panel.line; anchors.horizontalCenter: parent.horizontalCenter
                    transform: Translate { y: root.magLayout.total / 2 } }
        Item { width: 1; height: 4 }
        DockButton { host: root;
          transform: Translate { y: root.magLayout.total / 2 }
          glyph: "\u{f0493}"
          hint: "Dock settings"
          highlighted: root.settingsOpen
          onActivated: { root.menuIndex = -1; root.settingsOpen = !root.settingsOpen }
        }
      }

      // Real Wayland drops (a .desktop file from a file manager).
      DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: function(drop) {
          for (var i = 0; i < drop.urls.length; i++) {
            var u = String(drop.urls[i])
            if (u.slice(-8) !== ".desktop") continue
            root.addApp(u.split("/").pop(), root.indexAtPillY(drop.y))
          }
          drop.accept()
        }
      }
    }

    // Ghost of the icon being dragged inside the dock.
    ItemGlyph { host: root;
      visible: root.dragIndex >= 0 && !root.dragRemove
      x: pillBox.x + (pillBox.width - root.iconSize) / 2
      y: pillBox.y + root.dragY - root.iconSize / 2
      width: root.iconSize; height: root.iconSize
      z: 10
      item: root.dragIndex >= 0 ? root.dockItems[root.dragIndex] : null
    }

    // Hover label beside the dock.
    Rectangle {
      visible: root.hoverLabel !== "" && root.dragIndex < 0 && root.menuIndex < 0 && !root.settingsOpen
      x: panel.edgeX(root.gap + root.dockWidth + 8 + pillBg.grow, width)
      y: pillBox.y + root.hoverY - height / 2
      width: Math.min(root.tipWidth - 8, tipText.implicitWidth + 16)
      height: tipText.implicitHeight + 10
      radius: 6
      color: Commons.Color.tooltip.background
      border.width: 1
      border.color: Commons.Color.tooltip.border
      z: 15
      Text {
        id: tipText
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.tipWidth - 24)
        elide: Text.ElideRight
        text: root.hoverLabel
        color: Commons.Color.tooltip.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    // Right-click menu for a dock item.
    Rectangle {
      id: itemMenu
      visible: root.menuIndex >= 0
      x: panel.edgeX(root.gap + root.dockWidth + 8, width)
      y: Math.max(4, Math.min(panel.height - height - 4, pillBox.y + root.menuY - height / 2))
      width: root.menuWidth - 8
      height: menuCol.implicitHeight + 12
      radius: 10
      color: Util.alpha(Commons.Color.background, 0.98)
      border.width: 1
      border.color: panel.line
      z: 20

      Column {
        id: menuCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
        spacing: 2
        Text {
          width: parent.width
          leftPadding: 8
          topPadding: 2; bottomPadding: 4
          text: root.menuIndex >= 0 ? root.itemLabel(root.dockItems[root.menuIndex]) : ""
          color: panel.fg; opacity: 0.6
          elide: Text.ElideRight
          font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
        }
        MenuRow { host: root; label: "Open"; onActivated: { root.launchItem(root.dockItems[root.menuIndex]); root.menuIndex = -1 } }
        MenuRow { host: root; label: "Move up"; enabled: root.menuIndex > 0; onActivated: { root.moveItem(root.menuIndex, root.menuIndex - 1); root.menuIndex = -1 } }
        MenuRow { host: root; label: "Move down"; enabled: root.menuIndex >= 0 && root.menuIndex < root.dockItems.length - 1; onActivated: { root.moveItem(root.menuIndex, root.menuIndex + 1); root.menuIndex = -1 } }
        MenuRow { host: root; label: "Remove from dock"; danger: true; onActivated: { root.removeItem(root.menuIndex); root.menuIndex = -1 } }
      }
    }

    // ================= settings card =================
    Rectangle {
      id: settingsCard
      visible: opacity > 0
      opacity: root.settingsOpen ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      transform: Translate {
        x: (root.settingsOpen ? 0 : 14) * (root.onRight ? 1 : -1)
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
      x: panel.edgeX(root.gap + root.dockWidth + root.gap, width)
      y: Math.max(root.gap, Math.min(panel.height - height - root.gap, pillBox.y + pillBox.height - height))
      width: root.settingsWidth
      implicitHeight: settingsCol.implicitHeight + 28
      height: implicitHeight
      radius: root.radius
      color: Util.alpha(Commons.Color.background, Math.max(0.97, root.bgOpacity))
      border.width: 1
      border.color: panel.line
      z: 20

      Keys.onEscapePressed: root.settingsOpen = false

      Column {
        id: settingsCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10

        Item {
          width: parent.width; height: titleText.implicitHeight
          Text {
            id: titleText
            text: "Dock settings"
            color: panel.fg
            font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true
          }
          Text {
            anchors.right: parent.right
            text: "\u{f0156}"
            color: panel.fg; opacity: closeSettings.containsMouse ? 1 : 0.6
            font.family: Style.font.family; font.pixelSize: Style.font.title
            MouseArea { id: closeSettings; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsOpen = false }
          }
        }

        Segmented {
          host: root
          options: ["General", "Look", "Items", "Agents"]
          current: ["general", "look", "items", "agents"].indexOf(root.settingsTab)
          onPicked: function(i) { root.settingsTab = ["general", "look", "items", "agents"][i] }
        }

        // ---- General ----
        Column {
          visible: root.settingsTab === "general"
          width: parent.width
          spacing: 10
          SettingRow { host: root;
            label: "Position"
            Segmented { host: root;
              options: ["Left", "Right"]
              current: root.onRight ? 1 : 0
              onPicked: function(i) { saved.position = i === 0 ? "left" : "right" }
            }
          }
          SettingRow { host: root;
            label: "Floating gap"
            Stepper { host: root; value: saved.gap; from: 0; to: 48; step: 2; suffix: "px"; onStepped: function(v) { saved.gap = v } }
          }
          SettingRow { host: root;
            label: "Icon size"
            Stepper { host: root; value: saved.iconSize; from: 18; to: 56; step: 2; suffix: "px"; onStepped: function(v) { saved.iconSize = v } }
          }
          SettingRow { host: root;
            label: "Opacity"
            Stepper { host: root;
              value: Math.round(saved.opacity * 100); from: 30; to: 100; step: 5; suffix: "%"
              onStepped: function(v) { saved.opacity = v / 100 }
            }
          }
          SettingRow { host: root;
            label: "Reserve space (dock)"
            Switch { host: root; checked: saved.reserveCollapsed; onToggled: saved.reserveCollapsed = !saved.reserveCollapsed }
          }
          SettingRow { host: root;
            label: "Reserve space (panel)"
            Switch { host: root; checked: saved.reserveExpanded; onToggled: { saved.reserveExpanded = !saved.reserveExpanded; placeDebounce.restart() } }
          }


          Row {
            spacing: 8
            PillButton { host: root; label: "Reset icons"; onActivated: saved.dock = root.defaultDock }
            PillButton { host: root; label: "Reset width"; onActivated: { root.panelWidth = 520; saved.width = 520; placeDebounce.restart() } }
          }
        }

        // ---- Look: magnification, shapes, colours ----
        Column {
          visible: root.settingsTab === "look"
          width: parent.width
          spacing: 10
          SettingRow { host: root;
            label: "Magnify on hover"
            Switch { host: root; checked: saved.magnify; onToggled: saved.magnify = !saved.magnify }
          }
          SettingRow { host: root;
            visible: saved.magnify
            label: "Magnified size"
            Stepper { host: root; value: Math.round(root.magMax * 100); from: 110; to: 240; step: 10; suffix: "%"
                      onStepped: function(v) { saved.magnifyScale = v / 100 } }
          }
          SettingRow { host: root;
            visible: saved.magnify
            label: "Reach"
            Stepper { host: root; value: saved.magnifyRange; from: 1; to: 4; step: 1; suffix: " icons"
                      onStepped: function(v) { saved.magnifyRange = v } }
          }
          ChipFlow { host: root; label: "Dock shape"; value: saved.dockShape
            options: root.dockShapes.map(function(v) { return { value: v, label: v.charAt(0).toUpperCase() + v.slice(1) } })
            onPicked: function(v) { saved.dockShape = v } }
          ChipFlow { host: root; label: "Icon shape"; value: saved.iconShape
            options: root.iconShapes.map(function(v) { return { value: v, label: v.charAt(0).toUpperCase() + v.slice(1) } })
            onPicked: function(v) { saved.iconShape = v } }
          ChipFlow { host: root; label: "Icon tiles"; value: saved.iconPlate
            options: [{ value: "hover", label: "On hover" }, { value: "always", label: "Always" }, { value: "outline", label: "Outline" }]
            onPicked: function(v) { saved.iconPlate = v } }
          ChipFlow { host: root; label: "Dock colour"; value: saved.dockColor
            options: [{ value: "theme", label: "Theme" }].concat(Object.keys(root.dockColors).map(function(k) {
              return { value: k, label: k.charAt(0).toUpperCase() + k.slice(1), swatch: root.dockColors[k] } }))
            onPicked: function(v) { saved.dockColor = v } }
          ChipFlow { host: root; label: "Accent"; value: saved.accentColor
            options: [{ value: "theme", label: "Theme" }].concat(Object.keys(root.accentColors).map(function(k) {
              return { value: k, label: k.charAt(0).toUpperCase() + k.slice(1), swatch: root.accentColors[k] } }))
            onPicked: function(v) { saved.accentColor = v } }
          ChipFlow { host: root; label: "Border"; value: saved.dockBorder
            options: [{ value: "subtle", label: "Subtle" }, { value: "accent", label: "Accent" }, { value: "none", label: "None" }]
            onPicked: function(v) { saved.dockBorder = v } }
        }

        // ---- Items: programs, spacers, dividers ----
        Column {
          visible: root.settingsTab === "items"
          width: parent.width
          spacing: 8

          Row {
            spacing: 8
            PillButton { host: root; label: "+ Spacer"; onActivated: root.addItem({ type: "spacer" }) }
            PillButton { host: root; label: "+ Divider"; onActivated: root.addItem({ type: "divider" }) }
          }

          Text { text: "Programs"; color: panel.fg; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Field { id: appSearch; host: root; width: parent.width; placeholder: "Search installed apps…" }

          ListView {
            id: appList
            width: parent.width
            height: 210
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: root.settingsOpen && root.settingsTab === "items" ? root.appResults(appSearch.text) : []
            delegate: Rectangle {
              id: appRow
              required property var modelData
              readonly property int dockIndex: root.dockIndexOfApp(modelData.id)
              width: appList.width
              height: 30
              radius: 6
              color: appRowMouse.containsMouse ? Util.alpha(panel.fg, 0.08) : "transparent"
              Image {
                id: appRowIcon
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                width: 18; height: 18
                sourceSize: Qt.size(36, 36)
                asynchronous: true
                source: root.itemIcon({ type: "app", id: appRow.modelData.id })
              }
              Text {
                anchors { left: appRowIcon.right; leftMargin: 8; right: appRowState.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                text: appRow.modelData.name
                elide: Text.ElideRight
                color: panel.fg
                font.family: Style.font.family; font.pixelSize: Style.font.body
              }
              Text {
                id: appRowState
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: appRow.dockIndex >= 0 ? (appRowMouse.containsMouse ? "Remove" : "\u{f012c}") : "+ Add"
                color: appRow.dockIndex >= 0 ? (appRowMouse.containsMouse ? Commons.Color.urgent : panel.accent) : panel.fg
                opacity: appRow.dockIndex >= 0 || appRowMouse.containsMouse ? 1 : 0.5
                font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                id: appRowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: appRow.dockIndex >= 0 ? root.removeItem(appRow.dockIndex) : root.addApp(appRow.modelData.id, -1)
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.line }
          Text { text: "Custom command"; color: panel.fg; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Row {
            width: parent.width
            spacing: 6
            Field { id: customGlyph; host: root; width: 44; placeholder: "\u{f0614}" }
            Field { id: customName; host: root; width: parent.width - 50; placeholder: "Name" }
          }
          Field { id: customCmd; host: root; width: parent.width; placeholder: "Command, e.g. omarchy-launch-editor" }
          PillButton {
            host: root
            label: "Add command"
            opacity: customCmd.text.trim() ? 1 : 0.5
            onActivated: {
              var cmd = customCmd.text.trim()
              if (!cmd) return
              root.addItem({ type: "cmd", name: customName.text.trim() || cmd.split(" ")[0],
                             glyph: customGlyph.text.trim(), command: cmd })
              customCmd.text = ""; customName.text = ""; customGlyph.text = ""
            }
          }
        }

        // ---- Agents ----
        Column {
          visible: root.settingsTab === "agents"
          width: parent.width
          spacing: 10

          Repeater {
            model: root.agents
            delegate: SettingRow { host: root;
              id: agentRow
              required property var modelData
              label: modelData.name
              Switch { host: root;
                checked: saved.hiddenAgents.indexOf(agentRow.modelData.id) < 0
                onToggled: {
                  var h = saved.hiddenAgents.slice()
                  var i = h.indexOf(agentRow.modelData.id)
                  if (i >= 0) h.splice(i, 1); else h.push(agentRow.modelData.id)
                  saved.hiddenAgents = h
                  if (root.opened) root.syncWindows(false)
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: 4
            Text { text: "Start folder for new sessions"; color: panel.fg; opacity: 0.8; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
            Rectangle {
              width: parent.width; height: 28; radius: 6
              color: Util.alpha(panel.fg, 0.06)
              border.width: 1
              border.color: cwdInput.activeFocus ? panel.accent : panel.line
              TextInput {
                id: cwdInput
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                text: saved.cwd
                color: panel.fg
                selectByMouse: true
                font.family: Style.font.family; font.pixelSize: Style.font.body
                onEditingFinished: saved.cwd = text.trim()
                Keys.onEscapePressed: root.settingsOpen = false
                Text {
                  visible: !cwdInput.text && !cwdInput.activeFocus
                  anchors.verticalCenter: parent.verticalCenter
                  text: "~ (home)"
                  color: panel.fg; opacity: 0.4
                  font: cwdInput.font
                }
              }
            }
          }


        }

        Text {
          width: parent.width
          wrapMode: Text.Wrap
          text: "Drag icons to reorder, or off the dock to remove. Right-click an icon for more. Drag apps here from the launcher."
          color: panel.fg; opacity: 0.5
          font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
      }
    }
  }

  // ================= components =================

  // One icon in the dock. Click launches, drag reorders, drag off removes,
  // right-click opens the item menu.
  component DockItem: Item {
    id: di
    property var host: null
    required property var modelData
    required property int index
    readonly property bool isIncoming: !!modelData && modelData.placeholder === true
    readonly property bool isDragged: !isIncoming && host.dragIndex === index
    readonly property bool isPlaceholder: isIncoming || isDragged
    readonly property var item: isPlaceholder ? modelData.item : modelData
    readonly property bool isSpacer: !!item && item.type === "spacer"
    readonly property bool isDivider: !!item && item.type === "divider"
    readonly property bool isIcon: !isSpacer && !isDivider
    width: host.dockWidth - 8
    height: host.itemHeight(item)
    readonly property real magScale: host.magLayout.scales[index] || 1
    readonly property bool hovered: diMouse.containsMouse && host.dragIndex < 0
    z: magScale > 1.01 ? 1 + magScale : 0

    // Everything drawn for the entry, scaled from the screen-edge side and
    // shifted apart while the dock magnifies; clicks stay on the base cell.
    Item {
      id: body
      anchors.fill: parent
      opacity: di.isDragged && host.dragRemove ? 0 : 1
      transform: [
        Scale {
          origin.x: host.onRight ? body.width : 0
          origin.y: body.height / 2
          xScale: di.magScale
          yScale: di.magScale
        },
        Translate {
          x: (di.magScale - 1) * 4 * (host.onRight ? 1 : -1)
          y: (host.magLayout.shifts[di.index] || 0) + host.dragShift(di.index)
          Behavior on y { enabled: host.dragIndex >= 0; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
      ]

      Rectangle {
        id: plate
        readonly property string shape: saved.iconShape
        readonly property bool diamond: shape === "diamond"
        readonly property string mode: saved.iconPlate
        anchors.centerIn: parent
        width: (host.iconSize + 8) * (diamond && di.isIcon ? 0.8 : 1)
        height: di.isIcon ? width : di.height - 2
        rotation: diamond && di.isIcon ? 45 : 0
        radius: !di.isIcon ? 4
          : shape === "circle" ? width / 2
          : shape === "squircle" ? width * 0.36
          : shape === "square" ? 2
          : shape === "diamond" ? 4 : 8
        readonly property bool always: di.isIcon && mode === "always"
        color: di.isPlaceholder ? Util.alpha(host.accent, 0.15)
          : di.hovered ? Util.alpha(host.fg, di.isIcon ? (always ? 0.16 : 0.10) : 0.06)
          : always ? Util.alpha(host.fg, 0.07) : "transparent"
        border.width: di.isPlaceholder || (di.isIcon && mode === "outline") ? 1 : 0
        border.color: di.isPlaceholder ? host.accent : (di.hovered ? host.accent : host.line)
        Behavior on color { ColorAnimation { duration: 90 } }
      }

      // Divider line; a spacer is just room.
      Rectangle {
        visible: di.isDivider
        anchors.centerIn: parent
        width: host.iconSize; height: 1
        color: host.line
        opacity: di.isPlaceholder ? 0.5 : 1
      }

      ItemGlyph {
        host: di.host
        visible: di.isIcon
        anchors.centerIn: parent
        width: host.iconSize; height: host.iconSize
        item: di.item
        opacity: di.isPlaceholder ? 0.4 : 1
      }
    }

    MouseArea {
      id: diMouse
      anchors.fill: parent
      // Not isPlaceholder: the dragged item's own area holds the grab.
      enabled: !di.isIncoming
      hoverEnabled: true
      preventStealing: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: host.dragIndex >= 0 ? Qt.ClosedHandCursor : (di.isIcon ? Qt.PointingHandCursor : Qt.OpenHandCursor)
      property point start
      property bool moved: false

      onContainsMouseChanged: {
        if (containsMouse && host.dragIndex < 0 && di.isIcon) {
          host.hoverLabel = host.itemLabel(di.item)
          host.hoverY = di.mapToItem(host.pillItem, 0, di.height / 2).y
        } else if (!containsMouse && host.hoverLabel === host.itemLabel(di.item)) {
          host.hoverLabel = ""
        }
      }
      onPressed: function(mouse) {
        start = Qt.point(mouse.x, mouse.y)
        moved = false
      }
      onPositionChanged: function(mouse) {
        if (!pressed || !(mouse.buttons & Qt.LeftButton)) return
        if (!moved && Math.abs(mouse.y - start.y) + Math.abs(mouse.x - start.x) < 8) return
        var p = di.mapToItem(host.pillItem, mouse.x, mouse.y)
        if (!moved) {
          moved = true
          host.hoverLabel = ""
          host.menuIndex = -1
          host.dropIndex = di.index
          host.dragIndex = di.index
        }
        host.dragY = p.y
        host.dragRemove = p.x < -host.dockWidth * 0.6 || p.x > host.pillItem.width + host.dockWidth * 0.6
        host.dropIndex = host.indexAtPillY(p.y)
      }
      onReleased: function(mouse) {
        if (!moved) return
        var from = host.dragIndex, to = host.dropIndex, remove = host.dragRemove
        host.dragIndex = -1; host.dropIndex = -1; host.dragRemove = false
        if (from < 0) return
        if (remove) host.removeItem(from)
        else if (to !== from) host.moveItem(from, to)
      }
      onCanceled: { host.dragIndex = -1; host.dropIndex = -1; host.dragRemove = false }
      onClicked: function(mouse) {
        if (moved) return
        if (mouse.button === Qt.RightButton) {
          host.settingsOpen = false
          host.menuY = di.mapToItem(host.pillItem, 0, di.height / 2).y
          host.menuIndex = host.menuIndex === di.index ? -1 : di.index
        } else {
          host.menuIndex = -1
          host.launchItem(di.item)
        }
      }
    }
  }

  // App icon or glyph for a dock item.
  component ItemGlyph: Item {
    id: ig
    property var host: null
    property var item: null
    readonly property string src: host.itemIcon(item)
    Image {
      anchors.fill: parent
      visible: ig.src !== ""
      source: ig.src
      // Room for the magnified size, so grown icons stay sharp
      sourceSize: Qt.size(ig.width * 3, ig.height * 3)
      smooth: true
      asynchronous: true
    }
    Text {
      anchors.centerIn: parent
      visible: ig.src === ""
      text: !ig.item ? "" : ig.item.type === "app" ? host.itemLabel(ig.item).charAt(0).toUpperCase() : (ig.item.glyph || "\u{f0614}")
      color: host.fg
      font.family: Style.font.family
      font.pixelSize: Math.max(8, Math.round(ig.height * 0.72))
      font.bold: !!ig.item && ig.item.type === "app"
    }
  }

  component DockButton: Item {
    id: btn
    property var host: null
    property string glyph: ""
    property string hint: ""
    property bool highlighted: false
    property real glyphRotation: 0
    signal activated()
    width: host.dockWidth - 8
    height: host.slot

    Rectangle {
      anchors.centerIn: parent
      width: host.iconSize + 8; height: host.iconSize + 8
      radius: 8
      color: btnMouse.containsMouse ? Util.alpha(host.fg, 0.10) : (btn.highlighted ? Util.alpha(host.accent, 0.18) : "transparent")
    }
    Text {
      anchors.centerIn: parent
      text: btn.glyph
      rotation: btn.glyphRotation
      color: btn.highlighted ? host.accent : host.fg
      font.family: Style.font.family
      font.pixelSize: Math.round(host.iconSize * 0.72)
    }
    MouseArea {
      id: btnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.activated()
      onContainsMouseChanged: {
        if (containsMouse) { host.hoverLabel = btn.hint; host.hoverY = btn.mapToItem(host.pillItem, 0, btn.height / 2).y }
        else if (host.hoverLabel === btn.hint) host.hoverLabel = ""
      }
    }
  }

  component PillButton: Rectangle {
    id: pb
    property var host: null
    property string label: ""
    signal activated()
    width: pbText.implicitWidth + 24
    height: pbText.implicitHeight + 12
    radius: 6
    color: pbMouse.containsMouse ? Util.alpha(host.accent, 0.30) : Util.alpha(host.accent, 0.16)
    border.width: 1
    border.color: Util.alpha(host.accent, 0.5)
    Text {
      id: pbText
      anchors.centerIn: parent
      text: pb.label
      color: host.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    MouseArea { id: pbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.activated() }
  }

  component MenuRow: Rectangle {
    id: mr
    property var host: null
    property string label: ""
    property bool danger: false
    signal activated()
    width: parent ? parent.width : 0
    height: 28
    radius: 6
    opacity: enabled ? 1 : 0.4
    color: mrMouse.containsMouse && enabled ? Util.alpha(danger ? Commons.Color.urgent : host.fg, 0.12) : "transparent"
    Text {
      anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 }
      text: mr.label
      color: mr.danger ? Commons.Color.urgent : host.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    MouseArea { id: mrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (mr.enabled) mr.activated() }
  }

  component SettingRow: Item {
    id: sr
    property var host: null
    property string label: ""
    default property alias control: slotItem.data
    width: parent ? parent.width : 0
    height: Math.max(26, slotItem.height)
    Text {
      anchors { left: parent.left; verticalCenter: parent.verticalCenter }
      text: sr.label
      color: host.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    Item {
      id: slotItem
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  component Segmented: Row {
    id: seg
    property var host: null
    property var options: []
    property int current: 0
    signal picked(int index)
    spacing: 4
    Repeater {
      model: seg.options
      delegate: Rectangle {
        id: segItem
        required property string modelData
        required property int index
        width: segText.implicitWidth + 20
        height: 24
        radius: 6
        color: index === seg.current ? Util.alpha(host.accent, 0.35) : (segMouse.containsMouse ? Util.alpha(host.fg, 0.08) : Util.alpha(host.fg, 0.04))
        border.width: 1
        border.color: index === seg.current ? host.accent : host.line
        Text { id: segText; anchors.centerIn: parent; text: segItem.modelData; color: host.fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        MouseArea { id: segMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(segItem.index) }
      }
    }
  }

  // A label over a wrapping row of chips; a chip with a swatch shows its colour.
  component ChipFlow: Column {
    id: cf
    property var host: null
    property string label: ""
    property var options: []
    property string value: ""
    signal picked(string value)
    width: parent ? parent.width : 0
    spacing: 5
    Text { text: cf.label; color: host.fg; font.family: Style.font.family; font.pixelSize: Style.font.body }
    Flow {
      width: parent.width
      spacing: 4
      Repeater {
        model: cf.options
        delegate: Rectangle {
          id: chip
          required property var modelData
          readonly property bool chosen: modelData.value === cf.value
          width: chipRow.implicitWidth + 16
          height: 24
          radius: 6
          color: chosen ? Util.alpha(host.accent, 0.35) : (chipMouse.containsMouse ? Util.alpha(host.fg, 0.08) : Util.alpha(host.fg, 0.04))
          border.width: 1
          border.color: chosen ? host.accent : host.line
          Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
              visible: !!chip.modelData.swatch
              anchors.verticalCenter: parent.verticalCenter
              width: 10; height: 10; radius: 5
              color: chip.modelData.swatch || "transparent"
              border.width: 1
              border.color: Util.alpha(host.fg, 0.3)
            }
            Text { text: chip.modelData.label; color: host.fg; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          }
          MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cf.picked(chip.modelData.value) }
        }
      }
    }
  }

  component Stepper: Row {
    id: st
    property var host: null
    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1
    property string suffix: ""
    signal stepped(int v)
    spacing: 4
    Repeater {
      model: ["−", "value", "+"]
      delegate: Rectangle {
        id: stItem
        required property string modelData
        readonly property bool isValue: modelData === "value"
        width: isValue ? 52 : 24
        height: 24
        radius: 6
        color: isValue ? "transparent" : (stMouse.containsMouse ? Util.alpha(host.fg, 0.12) : Util.alpha(host.fg, 0.05))
        border.width: isValue ? 0 : 1
        border.color: host.line
        Text {
          anchors.centerIn: parent
          text: stItem.isValue ? st.value + st.suffix : stItem.modelData
          color: host.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        MouseArea {
          id: stMouse
          anchors.fill: parent
          enabled: !stItem.isValue
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var v = st.value + (stItem.modelData === "+" ? st.step : -st.step)
            st.stepped(Math.max(st.from, Math.min(st.to, v)))
          }
        }
      }
    }
  }

  component Field: Rectangle {
    id: fld
    property var host: null
    property alias text: fldInput.text
    property string placeholder: ""
    height: 28
    radius: 6
    color: Util.alpha(host.fg, 0.06)
    border.width: 1
    border.color: fldInput.activeFocus ? host.accent : host.line
    TextInput {
      id: fldInput
      anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
      verticalAlignment: TextInput.AlignVCenter
      clip: true
      color: host.fg
      selectByMouse: true
      font.family: Style.font.family; font.pixelSize: Style.font.body
      Keys.onEscapePressed: host.settingsOpen = false
      Text {
        visible: !fldInput.text && !fldInput.activeFocus
        anchors.verticalCenter: parent.verticalCenter
        text: fld.placeholder
        color: host.fg; opacity: 0.4
        font: fldInput.font
      }
    }
  }

  component Switch: Rectangle {
    id: sw
    property var host: null
    property bool checked: false
    signal toggled()
    width: 38; height: 22; radius: 11
    color: checked ? Util.alpha(host.accent, 0.6) : Util.alpha(host.fg, 0.12)
    border.width: 1
    border.color: checked ? host.accent : host.line
    Rectangle {
      width: 16; height: 16; radius: 8
      y: 3
      x: sw.checked ? sw.width - width - 3 : 3
      color: host.fg
      Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
  }
}

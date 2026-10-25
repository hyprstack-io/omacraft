import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "MenuModel.js" as MenuModel
import "LauncherStyles.js" as Styles

Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Plugin lifecycle hooks. The host calls open(payloadJson) after
  // `omarchy-shell shell summon omarchy.menu ...` and close() when hidden.
  property string pendingInitialMenu: "root"

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }

    if (payload.fontFamily) root.fontFamily = payload.fontFamily

    if (payload.mode === "select" || payload.mode === "input") {
      root.openDmenu(payload)
    } else {
      root.openRoute(payload.initialMenu || payload.menu || "root")
    }
  }

  function close() {
    root.cancel()
  }

  function refresh() {
    defaultMenuFile.reload()
    userMenuFile.reload()
    return "ok"
  }

  function ping() { return "ok" }

  property string fontFamily: Style.font.menuFamily
  // JSONC menu definitions. The shell parses both at startup and merges
  // the user file on top of the defaults, so the keybind → IPC → visible
  // path doesn't have to shell out to bash + jq on every open.
  property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  property var defaultMenuItems: []
  property var userMenuItems: []
  property bool opened: false
  property string mode: "menu"
  readonly property bool dmenuActive: mode === "select" || mode === "input"
  property string dmenuPrompt: ""
  property var dmenuOptions: []
  property string selectionFile: ""
  property string doneFile: ""
  property int dmenuWidth: 300
  property int dmenuMaxHeight: 0
  property bool requestActive: false
  property bool rowsLoaded: false
  property string activeMenu: "root"
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false

  // Dragging an app out to the Agent Dock (omacraft.agentdock). The launcher
  // keeps the pointer grab for the whole drag, so the dock can't get a
  // Wayland drop; it tracks the pointer itself and takes the drop over IPC.
  property var appDrag: null              // { appId, appIcon, label }
  property var appDragPending: null
  property point appDragPos: Qt.point(0, 0)
  property bool appDragSuppressClick: false

  function appDragPress(kind, appId, appIcon, label, item, mouse) {
    root.appDragSuppressClick = false
    if (mouse.button !== Qt.LeftButton || kind !== "app" || !appId) { root.appDragPending = null; return }
    var p = item.mapToItem(null, mouse.x, mouse.y)
    root.appDragPending = { appId: appId, appIcon: appIcon, label: label, x: p.x, y: p.y }
  }

  // True while an app drag is in progress (the caller then skips hover).
  function appDragMove(item, mouse) {
    var pending = root.appDragPending
    if (!pending) return false
    var p = item.mapToItem(null, mouse.x, mouse.y)
    if (!root.appDrag) {
      if (Math.abs(p.x - pending.x) + Math.abs(p.y - pending.y) < 12) return false
      root.appDrag = pending
      Quickshell.execDetached(["omarchy-shell", "agentdock", "dragStart", pending.appId])
    }
    root.appDragPos = p
    return true
  }

  function appDragRelease() {
    root.appDragPending = null
    if (!root.appDrag) return
    root.appDrag = null
    root.appDragSuppressClick = true
    Quickshell.execDetached(["omarchy-shell", "agentdock", "dragEnd"])
    root.cancel()
  }
  property int requestSerial: 0
  property int applySerial: 0
  property var items: ({})
  property var itemOrder: []
  property var navStack: []
  property var providersLoaded: ({})
  property var providerQueue: []
  property int providerRevision: 0

  // Shared application engine (entries, hidden filters, icons, launch,
  // removal), owned by the shell and also used by the standalone launcher.
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
  property bool deleteConfirmOpen: false
  property var deleteTarget: null
  onOpenedChanged: if (!opened) { deleteConfirmOpen = false; deleteTarget = null }
  // ------------------------------------------------------------- styles
  //
  // Layout and color scheme come from ~/.config/omarchy/launcher-style.json,
  // written by `omarchy-launcher-style`, the Style > Launcher menu, or
  // Ctrl+L / Ctrl+T inside the menu. See LauncherStyles.js for the catalog.
  property string styleFilePath: Quickshell.env("HOME") + "/.config/omarchy/launcher-style.json"
  property string layoutId: "classic"
  property string schemeId: "omarchy"
  readonly property var layoutDef: Styles.layout(layoutId)
  readonly property var schemeDef: Styles.scheme(schemeId)
  // Motion: how the launcher arrives (see Styles.transitions), how fast
  // (1 = as listed, 2 = twice as fast), and whether switching layout or
  // colours while it is open glides rather than jumps.
  property string transitionId: "auto"
  property real transitionSpeed: 1
  property bool animateLayouts: true
  property bool animateColors: true
  readonly property var transitionDef: Styles.transition(transitionId)
  readonly property bool customTransition: transitionDef.id !== "auto"
  readonly property real speedFactor: Math.max(0.25, Math.min(3, Number(transitionSpeed) || 1))
  readonly property var easings: ({ OutCubic: Easing.OutCubic, OutBack: Easing.OutBack, OutBounce: Easing.OutBounce,
                                    OutQuint: Easing.OutQuint, OutElastic: Easing.OutElastic, Linear: Easing.Linear })
  readonly property bool themed: schemeDef.id !== "omarchy"
  // Caller-driven prompts carry their own width and text-only rows, so the
  // icon layouts hand them to the classic card (still in the active colors).
  readonly property string layoutKind: (dmenuActive && (layoutDef.kind === "grid" || layoutDef.kind === "strip")) ? "classic" : layoutDef.kind
  // Presets with a base (Right drawer, Command palette, ...) draw as that
  // layout; only their placement and size differ (see panel.modernRect).
  readonly property string effectiveLayout: layoutKind === "classic" ? "classic" : Styles.baseOf(layoutDef)
  readonly property bool onRight: layoutDef.side === "right"
  readonly property bool atTop: layoutDef.edge === "top"
  readonly property bool atBottom: layoutDef.edge === "bottom"
  property string toastText: ""
  property string wallpaperSource: ""
  readonly property string wallpaperPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  property string hostName: ""

  // Bound to the central [menu] section in shell.toml via Color.qml, unless
  // a launcher color scheme replaces them. Each color already includes its
  // alpha companion (composed in the singleton), so consumers can drop them
  // straight into a Rectangle.
  property color background: themed ? schemeDef.bg : Commons.Color.menu.background
  property color foreground: themed ? schemeDef.fg : Commons.Color.menu.text
  property color border: themed ? Util.alpha(schemeDef.sel, 0.55) : Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: themed ? Util.alpha(schemeDef.bg, 0.45) : Commons.Color.menu.scrim
  property color selectedBackground: themed ? schemeDef.sel : Commons.Color.menu.selectedBackground
  property color selectedText: themed ? Styles.textOn(schemeDef) : Commons.Color.menu.selectedText
  property color selectedBorder: themed ? Util.alpha(schemeDef.sel, 0) : Commons.Color.menu.selectedBorder
  property color surfaceAlt: themed ? schemeDef.alt : Util.alpha(Commons.Color.menu.text, 0.07)
  property color accent: themed ? schemeDef.sel : Commons.Color.accent
  property color accentText: themed ? Styles.textOn(schemeDef) : Util.alpha(Commons.Color.background, 1)
  property color glyphAccent: themed ? Styles.readableAccent(schemeDef) : Commons.Color.accent
  property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", selectedBorder, 0)

  // A scheme change while the launcher is open blends the colours over.
  readonly property bool blendColors: animateColors && opened
  readonly property int blendMs: Math.round(280 / speedFactor)
  Behavior on background { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on foreground { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on border { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on scrim { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on selectedBackground { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on selectedText { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on surfaceAlt { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on accent { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on accentText { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  Behavior on glyphAccent { enabled: root.blendColors; ColorAnimation { duration: root.blendMs; easing.type: Easing.OutCubic } }
  readonly property real rowReservedBorderLeft: Border.left(selectedBorderSpec)
  readonly property real rowReservedBorderRight: Border.right(selectedBorderSpec)
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int baseRowHeight: Math.max(Style.space(50), Style.font.body + Style.spacing.rowPaddingX * 2)
  property int detailRowHeight: Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  // How much of the first hidden row stays visible at the fold — enough to
  // read as a cut-off row rather than a bottom border.
  property int rowPeek: Math.round(baseRowHeight * 0.55)
  property int rowSpacing: Style.spacing.xs
  property int dividerHeight: Style.space(17)
  property bool searchDivider: false
  property int layoutSerial: 0
  property int cardWidth: Math.min(root.dmenuActive ? Style.space(root.dmenuWidth) : ((root.activeMenu === "trigger.capture.screenrecord" || root.activeMenu === "style.font") ? Style.space(520) : Style.space(300)), panel.width - Style.gapsOut * 2)
  property int visibleRowsHeight: root.dmenuActive ? dmenuRowListHeight(layoutSerial, displayModel.count, filterText) : rowListHeight(layoutSerial, displayModel.count, filterText, searchDivider)
  property int cardHeight: root.dmenuActive
    ? Math.min(contentMargin * 2 + headerHeight + (mode === "input" ? 0 : contentSpacing + visibleRowsHeight), panel.height - Style.gapsOut * 2)
    : Math.min(contentMargin * 2 + headerHeight + contentSpacing + visibleRowsHeight, panel.height - Style.gapsOut * 2)

  // Metrics for the non-classic layouts.
  readonly property var layoutRadii: ({ sidebar: 14, spotlight: 18, split: 16, launchpad: 22, grid: 18, dock: 24, topbar: 10 })
  readonly property int layoutRadius: layoutRadii[effectiveLayout] !== undefined ? Style.space(layoutRadii[effectiveLayout]) : root.cornerRadius
  readonly property int itemRadius: Math.max(Style.space(6), Math.round(layoutRadius * 0.6))
  readonly property int searchHeight: effectiveLayout === "topbar" ? Style.space(36) : Style.space(effectiveLayout === "launchpad" || effectiveLayout === "spotlight" ? 52 : 44)
  readonly property bool searchIsPill: effectiveLayout === "launchpad" || effectiveLayout === "spotlight" || effectiveLayout === "dock"
  readonly property int listRowBase: Style.space(effectiveLayout === "spotlight" ? 50 : (effectiveLayout === "split" ? 44 : 46))
  readonly property int listRowDetail: Style.space(effectiveLayout === "spotlight" ? 62 : 58)
  readonly property int listIconSize: Style.space(effectiveLayout === "spotlight" ? 30 : 24)
  readonly property int gridIconSize: Style.space(effectiveLayout === "launchpad" ? 76 : 54)
  readonly property int gridCellHeight: Style.space(effectiveLayout === "launchpad" ? 156 : 124)
  readonly property int dockCell: Style.space(98)
  readonly property int dockIconSize: Style.space(52)
  readonly property var currentRow: rowAt(layoutSerial, selectedIndex, cursorActive)

  function rowAt(_serial, index, active) {
    return active && index >= 0 && index < displayModel.count ? displayModel.get(index) : null
  }

  function showsDetails(detail) {
    if (!detail) return false
    if (root.filterText || root.dmenuActive) return true
    return root.effectiveLayout === "spotlight" || root.effectiveLayout === "split"
  }

  function listRowHeight(detail) {
    return root.showsDetails(detail) ? root.listRowDetail : root.listRowBase
  }

  function promptLabel() {
    if (root.dmenuActive) return root.dmenuPrompt
    if (root.activeMenu === "root") return root.effectiveLayout === "launchpad" || root.effectiveLayout === "dock" ? "Omarchy" : "Go"
    var entry = root.item(root.activeMenu)
    return entry ? (entry.title || entry.label) : "Go"
  }

  function promptGlyph() {
    if (!root.dmenuActive && root.activeMenu !== "root") return "󰁍"
    return ""
  }

  function applyStyleText(raw) {
    var text = String(raw || "").trim()
    var parsed = ({})
    if (text) {
      // A writer truncates before it writes; a half-written file keeps the
      // last good style rather than flashing back to the defaults.
      try { parsed = JSON.parse(text) || ({}) } catch (e) { return }
    }
    root.transitionId = Styles.transition(String(parsed.transition || "auto")).id
    root.transitionSpeed = Number(parsed.speed) > 0 ? Number(parsed.speed) : 1
    root.animateLayouts = parsed.animateLayouts !== false
    root.animateColors = parsed.animateColors !== false
    root.beginMorph(Styles.layout(String(parsed.layout || "classic")).id)
    root.layoutId = Styles.layout(String(parsed.layout || "classic")).id
    root.schemeId = Styles.scheme(String(parsed.scheme || "omarchy")).id
  }

  // Switching layout while open: the card glides to its new place and size
  // and the content cross-fades, instead of jumping.
  property bool morphing: false
  property real morphProgress: 1
  readonly property real morphScale: 0.95 + 0.05 * morphProgress
  readonly property real morphOpacity: 0.25 + 0.75 * morphProgress
  readonly property int morphMs: Math.round(340 / speedFactor)
  function beginMorph(nextLayout) {
    if (!root.opened || !root.animateLayouts || nextLayout === root.layoutId) return
    root.morphing = true
    morphAnim.restart()
  }

  function setStyle(layoutId, schemeId) {
    var prevKind = root.layoutKind
    root.beginMorph(Styles.layout(layoutId).id)
    root.layoutId = Styles.layout(layoutId).id
    root.schemeId = Styles.scheme(schemeId).id
    if (root.layoutKind !== prevKind) root.cursorActive = true
    styleWriteDelay.restart()
    Qt.callLater(function() { if (displayModel.count > 0) root.revealCursor() })
  }

  function cycleLayout(delta) {
    root.setStyle(Styles.cycle(Styles.layouts, root.layoutId, delta), root.schemeId)
    root.showToast(root.layoutDef.icon + "  " + root.layoutDef.name + " layout")
  }

  function cycleScheme(delta) {
    root.setStyle(root.layoutId, Styles.cycle(Styles.schemes, root.schemeId, delta))
    root.showToast("󰏘  " + root.schemeDef.name)
  }

  function showToast(text) {
    root.toastText = text
    toastTimer.restart()
  }

  function reloadWallpaper() {
    // The background is a symlink that changes target in place; drop the
    // source first so the uncached Image re-reads it.
    root.wallpaperSource = ""
    Qt.callLater(function() { root.wallpaperSource = Util.fileUrl(root.wallpaperPath) })
  }

  function activeView() {
    if (root.layoutKind === "list") return modernList
    if (root.layoutKind === "grid") return iconGrid
    if (root.layoutKind === "strip") return stripList
    return resultList
  }

  function gridColumns() {
    return Math.max(1, Math.floor(iconGrid.width / Math.max(1, iconGrid.cellWidth)))
  }

  // Arrow keys in the grid move in two dimensions. Left/right wrap through
  // the whole list; up/down keep the column and wrap top to bottom.
  function moveGrid(dx, dy) {
    var count = displayModel.count
    if (count === 0) return

    root.disarmPointer()
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = 0
      root.revealCursor()
      return
    }

    var cols = root.gridColumns()
    var next = root.selectedIndex
    if (dx !== 0) {
      next = (next + dx + count) % count
    } else if (dy !== 0) {
      var col = next % cols
      next += dy * cols
      if (next >= count) {
        // A partial last row below: land on its last item first, then wrap.
        var lastRow = Math.floor((count - 1) / cols)
        next = Math.floor(root.selectedIndex / cols) < lastRow ? count - 1 : col
      } else if (next < 0) {
        next = Math.min(count - 1, Math.floor((count - 1) / cols) * cols + col)
      }
    }
    root.selectedIndex = next
    root.revealCursor()
  }

  // Arrow handling for grid and strip layouts, where left/right move the
  // cursor instead of walking the menu tree. Backspace still goes back.
  function handleSpatialKey(event) {
    var grid = root.layoutKind === "grid"
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false
    switch (event.key) {
    case Qt.Key_Left: if (grid) root.moveGrid(-1, 0); else root.select(-1); return true
    case Qt.Key_Right: if (grid) root.moveGrid(1, 0); else root.select(1); return true
    case Qt.Key_Up: if (grid) root.moveGrid(0, -1); else root.select(-1); return true
    case Qt.Key_Down: if (grid) root.moveGrid(0, 1); else root.select(1); return true
    case Qt.Key_Backspace:
      if (root.filterText) return false
      root.goBack()
      return true
    }
    return false
  }

  function finishRequest(selection) {
    if (!root.requestActive || !root.doneFile) {
      root.opened = false
      return
    }

    var activeSelectionFile = root.selectionFile
    var activeDoneFile = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""

    if (selection === null || selection === undefined) {
      resultProc.command = ["bash", "-c", ": > " + Util.shellQuote(activeDoneFile)]
    } else {
      resultProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(selection) + " > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    }
    resultProc.running = true
  }

  function runAction(action) {
    var command = String(action || "")
    if (!command) return

    Util.execDetached(command)
  }

  // Menu rows only surface their detail while a search is narrowing them;
  // dmenu rows carry caller-supplied subtext that must always be visible.
  function rowHeightForDetail(detail) {
    return (root.filterText || root.dmenuActive) && detail ? root.detailRowHeight : root.baseRowHeight
  }

  // Height the card can devote to rows before running off the screen — or
  // past the frozen top edge once a search has pinned the card in place.
  // Uses panel.cardTop rather than effectiveCardTop: the centered top is
  // derived from the card height, which this value feeds.
  function availableRowsHeight() {
    var top = panel.cardTop >= 0 ? panel.cardTop : Style.gapsOut
    var available = panel.height - top - Style.gapsOut - root.contentMargin * 2 - root.headerHeight - root.contentSpacing
    // The starting menu sets the ceiling along with the offset: drilling into
    // a longer submenu scrolls behind the fold instead of growing the card.
    if (panel.maxRowsHeight >= 0) available = Math.min(available, panel.maxRowsHeight)
    // A card that swallows the whole screen reads as a page, not a menu.
    return Math.min(available, Math.round(panel.height * 0.7))
  }

  // When every row fits, the list gets its full height. When they don't,
  // the card must end mid-row: a clipped row is what tells the eye there is
  // more below the fold, so never come out even on a row boundary.
  function foldedListHeight(totals, available) {
    var count = totals.length
    if (count === 0) return root.baseRowHeight
    if (totals[count - 1] <= available) return totals[count - 1]

    var peek = root.rowPeek
    var full = 0
    while (full < count && totals[full] <= available) full++
    while (full > 1 && totals[full - 1] + root.rowSpacing + peek > available) full--
    if (full < 1) return Math.max(available, root.baseRowHeight)

    return totals[full - 1] + root.rowSpacing + peek
  }

  function rowListHeight(_serial, _count, _filter, _divider) {
    if (displayModel.count === 0) return root.baseRowHeight

    var totals = []
    var total = 0
    var previousSection = ""

    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (i > 0) total += root.rowSpacing
      if (row.section === "drilldown" && previousSection !== "drilldown") total += root.dividerHeight
      total += root.rowHeightForDetail(row.detail)
      previousSection = row.section
      totals.push(total)
    }

    return foldedListHeight(totals, availableRowsHeight())
  }

  function dmenuRowListHeight(_serial, _count, _filter) {
    if (root.mode === "input") return 0
    if (displayModel.count === 0) return root.baseRowHeight

    var available = availableRowsHeight()
    if (root.dmenuMaxHeight > 0) available = Math.min(available, Style.space(root.dmenuMaxHeight))

    var totals = []
    var total = 0
    for (var i = 0; i < displayModel.count; i++) {
      if (i > 0) total += root.rowSpacing
      total += root.rowHeightForDetail(displayModel.get(i).detail)
      totals.push(total)
    }

    return foldedListHeight(totals, available)
  }

  function item(id) {
    return root.items[id] || null
  }

  // ------------------------------------------------------------------
  // JSONC → normalized item array. Mirrors the bash bin's jq pipeline so
  // the on-disk authoring format stays untouched.
  // ------------------------------------------------------------------

  function stripJsonc(raw) {
    return MenuModel.stripJsonc(raw)
  }

  function normalizeAliases(value) {
    return MenuModel.normalizeAliases(value)
  }

  function normalizeItem(id, raw) {
    return MenuModel.normalizeItem(id, raw)
  }

  function parseMenuJsonc(raw) {
    return MenuModel.parseMenuJsonc(raw)
  }

  // Merge defaults + user extension. Later entries override earlier ones
  // on a per-key basis (so the user can tweak label/icon/action without
  // re-declaring the whole row).
  function rebuildItemsFromSources() {
    var mergedMenu = MenuModel.mergeMenuSources(root.defaultMenuItems, root.userMenuItems)
    root.providerRevision += 1
    root.providersLoaded = ({})
    root.providerQueue = []
    root.items = mergedMenu.items
    root.itemOrder = mergedMenu.itemOrder
    root.rowsLoaded = true
    root.evaluateGuards()
    if (root.opened) {
      root.rebuildDisplay()
      if (!root.dmenuActive) {
        if (root.filterText.trim()) root.loadProvidersForSearch()
        else root.loadProviderForMenu(root.activeMenu)
      }
    }
  }

  // Each known provider is a tiny bash one-liner that enumerates a list and
  // emits one tab-delimited row per item: `label\tvalue\tcurrent`. The shell
  // turns those into menu items children of `menuId`. A `volatile` provider
  // re-runs every time its submenu is entered, so a font installed since the
  // shell started shows up without restarting it.
  readonly property var providers: ({
    "fonts": {
      script: "current=$(omarchy-font-current 2>/dev/null); omarchy-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
      icon: "",
      volatile: true,
      actionFor: function(value) { return "omarchy-font-set " + Util.shellQuote(value) }
    },
    "power-profiles": {
      script: "current=$(powerprofilesctl get 2>/dev/null); omarchy-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
      icon: "\udb81\udc0b",
      actionFor: function(value) { return "omarchy-powerprofiles-set autodetect " + Util.shellQuote(value) }
    }
  })

  function slugify(value) {
    return MenuModel.slugify(value)
  }

  // The apps provider is QML-native: rows come from the shared AppLibrary
  // (DesktopEntries) instead of a bash enumeration, so they carry image
  // icons, launch feedback, and uninstall support like the launcher.
  // Returns how many apps were merged, so callers can retry an empty load.
  function mergeAppRows() {
    if (!root.appLibrary) return 0

    var rows = root.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appLibrary.entrySubtext(entry)
      var aliases = subtext ? [subtext] : []
      try {
        if (entry.keywords && typeof entry.keywords.join === "function") aliases = aliases.concat(entry.keywords)
      } catch (e) { }
      appRows.push({
        id: "apps." + appId,
        parent: "apps",
        kind: "app",
        icon: "",
        appIcon: String(entry.icon || ""),
        appId: appId,
        label: root.appLibrary.entryName(entry),
        title: "",
        target: "",
        description: subtext,
        action: "",
        provider: "",
        aliases: aliases,
        when: "",
        checked: "",
        order: 0
      })
    }

    var merged = MenuModel.mergeAppRows(root.items, root.itemOrder, appRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
    return appRows.length
  }

  function startProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return
    if (entry.provider === "apps") {
      // The shell injects `shell` (and with it the app library) after this
      // plugin is created, and again on every hot reload, and DesktopEntries
      // may still be indexing. Only mark the provider loaded once apps actually
      // arrived; otherwise the Apps menu would stay empty for good.
      if (root.mergeAppRows() > 0) root.providersLoaded[id] = true
      return
    }
    var spec = root.providers[entry.provider]
    if (!spec) return

    root.providersLoaded[id] = true
    providerProc.menuId = id
    providerProc.providerKey = entry.provider
    providerProc.revision = root.providerRevision
    providerProc.collected = ""
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }

  function mergeProviderRows(rows, menuId, providerKey) {
    var spec = root.providers[providerKey]
    if (!spec) return
    var lines = String(rows || "").split("\n")
    var providerRows = []
    var takenIds = ({})
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split("\t")
      var label = parts[0] || ""
      var value = parts[1] || parts[0] || ""
      var current = parts[2] || ""
      if (!label) continue
      // Distinct values can slugify alike — Fira Code and Fira-Code both give
      // fira-code — and a repeated id is dropped, which would silently lose a
      // row from the list. Nudge it until it is the row's own.
      var rowId = menuId + "." + root.slugify(value)
      while (takenIds[rowId]) rowId += "-"
      takenIds[rowId] = true

      providerRows.push({
        id: rowId,
        parent: menuId,
        kind: "action",
        icon: (value === current) ? "✓" : (spec.icon || ""),
        label: label,
        title: "",
        target: "",
        description: "",
        action: spec.actionFor(value),
        provider: "",
        aliases: [],
        when: "",
        checked: "",
        order: 0
      })
    }
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, menuId, providerRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startNextProvider() {
    if (providerProc.running) return

    while (root.providerQueue.length > 0) {
      var id = root.providerQueue.shift()
      var entry = root.item(id)
      if (!entry || !entry.provider || root.providersLoaded[id]) continue

      root.startProviderForMenu(id)
      return
    }
  }

  // Entering a submenu is the one moment a volatile list is worth paying for
  // again: it may have been reshaped by the last pick from it. Search doesn't
  // invalidate, or every keystroke would restart the same enumeration.
  function invalidateVolatileProvider(id) {
    var entry = root.item(id)
    var spec = entry && entry.provider ? root.providers[entry.provider] : null
    if (spec && spec.volatile) root.providersLoaded[id] = false
  }

  function loadProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return

    // Native providers don't touch providerProc, so they never need to queue.
    if (entry.provider === "apps") {
      root.startProviderForMenu(id)
      return
    }

    if (providerProc.running) {
      if (root.providerQueue.indexOf(id) < 0) root.providerQueue = root.providerQueue.concat([id])
      return
    }

    root.startProviderForMenu(id)
  }

  function loadProvidersForSearch() {
    var active = root.item(root.activeMenu) ? root.activeMenu : "root"

    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (!entry || !entry.provider || root.providersLoaded[entry.id]) continue
      if (active !== "root" && entry.id !== active && !root.isDescendantOf(entry.id, active)) continue

      root.loadProviderForMenu(entry.id)
    }
  }

  function depthFor(id) {
    return MenuModel.depthFor(root.items, id)
  }

  function pathFor(id) {
    return MenuModel.pathFor(root.items, id)
  }

  function parentPathFor(id) {
    return MenuModel.parentPathFor(root.items, id)
  }

  function isDescendantOf(id, ancestorId) {
    return MenuModel.isDescendantOf(root.items, id, ancestorId)
  }

  function childCount(id) {
    return MenuModel.childCount(root.items, root.itemOrder, id)
  }

  // Guarded items are hidden when their `when:` evaluates false. Static
  // submenus are also hidden when none of their descendants are visible;
  // provider-backed menus stay visible because their rows load on demand.
  function isVisible(entry) {
    return MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry)
  }

  // Label with the ✓ marker baked in when `checked:` evaluated truthy.
  function labelFor(entry) {
    return MenuModel.labelFor(entry, root.checkedResults)
  }

  function searchableToken(value) {
    return MenuModel.searchableToken(value)
  }

  function leafIdFor(id) {
    return MenuModel.leafIdFor(id)
  }

  function nameSearchText(entry) {
    return MenuModel.nameSearchText(entry)
  }

  function termInSearchWords(term, text) {
    return MenuModel.termInSearchWords(term, text)
  }

  function descriptionTextMatches(query, text) {
    return MenuModel.descriptionTextMatches(query, text)
  }

  function matchesQuery(entry, query) {
    return MenuModel.matchesQuery(entry, query, root.isVisible(entry))
  }

  function searchScore(entry, query) {
    return MenuModel.searchScore(root.items, entry, query)
  }

  function displayRow(entry, detail, score, section) {
    return MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, entry, detail, score, section)
  }

  function rebuildDmenuDisplay() {
    displayModel.clear()
    root.searchDivider = false

    if (root.mode === "input") {
      layoutSerial += 1
      return
    }

    var query = root.filterText.trim().toLowerCase()
    for (var i = 0; i < root.dmenuOptions.length; i++) {
      // An option is "<label>", "<glyph>\t<label>", or
      // "<glyph>\t<label>\t<subtext>". The glyph never comes back with the
      // selection; the subtext renders under the label, filters alongside it,
      // and returns with the selection as a stable key for same-named rows.
      var parts = String(root.dmenuOptions[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (query && label.toLowerCase().indexOf(query) < 0
          && detail.toLowerCase().indexOf(query) < 0) continue
      displayModel.append({
        itemId: "dmenu." + i,
        kind: "dmenu",
        icon: icon,
        iconFont: "",
        appIcon: "",
        appId: "",
        label: label,
        target: "",
        detail: detail,
        path: "",
        childCount: 0,
        action: "",
        provider: "",
        score: i,
        section: ""
      })
    }

    layoutSerial += 1

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  function rebuildDisplay() {
    if (root.dmenuActive) {
      root.rebuildDmenuDisplay()
      return
    }

    displayModel.clear()

    if (!root.rowsLoaded) return

    var active = root.item(root.activeMenu) ? root.activeMenu : "root"
    root.activeMenu = active
    var rows = []
    var query = root.filterText.trim()
    root.searchDivider = false

    if (query) {
      var currentRows = []
      var drilldownRows = []

      for (var i = 0; i < root.itemOrder.length; i++) {
        var entry = root.item(root.itemOrder[i])
        if (!entry || entry.id === "root") continue
        if (!root.isDescendantOf(entry.id, active)) continue
        if (!root.matchesQuery(entry, query)) continue

        var detail = root.parentPathFor(entry.id)
        var row = root.displayRow(entry, detail, root.searchScore(entry, query))
        if (entry.parent === active) currentRows.push(row)
        else drilldownRows.push(row)
      }

      var searchSort = function(a, b) {
        if (a.score !== b.score) return a.score - b.score
        return a.path.localeCompare(b.path)
      }

      currentRows.sort(searchSort)
      drilldownRows.sort(searchSort)
      root.searchDivider = currentRows.length > 0 && drilldownRows.length > 0
      if (root.searchDivider) {
        for (var d = 0; d < drilldownRows.length; d++) drilldownRows[d].section = "drilldown"
      }
      rows = currentRows.concat(drilldownRows)
    } else {
      for (var j = 0; j < root.itemOrder.length; j++) {
        var child = root.item(root.itemOrder[j])
        if (!child || child.parent !== active) continue
        if (!root.isVisible(child)) continue
        rows.push(root.displayRow(child, child.description, child.order))
      }

      // DesktopEntries can reorder its values when an application starts.
      // Keep the Apps menu alphabetical independently of provider refreshes.
      if (active === "apps") {
        rows.sort(function(a, b) {
          var aLabel = String(a.label || "").toLowerCase()
          var bLabel = String(b.label || "").toLowerCase()
          if (aLabel < bLabel) return -1
          if (aLabel > bLabel) return 1
          var aId = String(a.itemId || "")
          var bId = String(b.itemId || "")
          if (aId < bId) return -1
          if (aId > bId) return 1
          return 0
        })
      }
    }

    for (var k = 0; k < rows.length; k++) displayModel.append(rows[k])
    layoutSerial += 1

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  // Contain alone parks the cursor row flush with the viewport edge, hiding
  // the neighbor entirely and losing the fold affordance. Keep the next
  // hidden row peeking past the cursor in the direction of travel.
  function revealCursor() {
    if (displayModel.count === 0) return
    if (root.layoutKind === "grid") {
      iconGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
      return
    }
    if (root.layoutKind !== "classic") {
      root.activeView().positionViewAtIndex(root.selectedIndex, ListView.Contain)
      return
    }
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)

    var item = resultList.itemAtIndex(root.selectedIndex)
    if (!item) return

    var reach = root.rowPeek + root.rowSpacing
    if (root.selectedIndex < displayModel.count - 1) {
      var maxY = Math.max(resultList.originY, resultList.originY + resultList.contentHeight - resultList.height)
      var overhang = item.y + item.height + reach - (resultList.contentY + resultList.height)
      if (overhang > 0) resultList.contentY = Math.min(resultList.contentY + overhang, maxY)
    }
    if (root.selectedIndex > 0) {
      var underhang = resultList.contentY - (item.y - reach)
      if (underhang > 0) resultList.contentY = Math.max(resultList.contentY - underhang, resultList.originY)
    }
  }

  function select(delta) {
    if (displayModel.count === 0) return

    root.disarmPointer()
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    revealCursor()
  }

  function setFilter(nextFilter) {
    panel.freezeCardTop()
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = root.mode !== "input"
    root.disarmPointer()
    if (!root.dmenuActive && root.filterText.trim()) root.loadProvidersForSearch()
    root.rebuildDisplay()
  }

  function setActiveMenu(id, pushHistory, fromPointer) {
    panel.freezeCardTop()
    if (!root.item(id)) id = "root"
    if (pushHistory && id !== root.activeMenu) root.navStack = root.navStack.concat([root.activeMenu])
    root.activeMenu = id
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    if (fromPointer) pointerGate.allowInitialSample()
    else root.disarmPointer()
    root.rebuildDisplay()
    root.invalidateVolatileProvider(id)
    root.loadProviderForMenu(id)
  }

  function goBack() {
    if (root.activeMenu === "root") return false

    if (root.navStack.length > 0) {
      var previous = root.navStack[root.navStack.length - 1]
      root.navStack = root.navStack.slice(0, root.navStack.length - 1)
      root.setActiveMenu(previous, false)
      return true
    }

    var active = root.item(root.activeMenu)
    root.setActiveMenu((active && active.parent) ? active.parent : "root", false)
    return true
  }

  function activateIndex(index, fromPointer) {
    if (root.deleteConfirmOpen) return
    if (root.dmenuActive) {
      if (root.mode === "input") {
        root.applyDmenuSelection(root.filterText)
        return
      }
      if (index < 0 || index >= displayModel.count) return
      var picked = displayModel.get(index)
      root.applyDmenuSelection(picked.detail ? picked.label + "\t" + picked.detail : picked.label)
      return
    }

    if (index < 0 || index >= displayModel.count) return

    var row = displayModel.get(index)
    if (row.kind === "menu" || row.kind === "link") {
      root.setActiveMenu(row.target || row.itemId, true, fromPointer)
    } else if (row.kind === "app") {
      var appId = row.appId
      var label = row.label
      applySerial = requestSerial
      opened = false
      filterText = ""
      if (root.appLibrary) root.appLibrary.launch(appId, label)
    } else {
      root.applySelected(row.itemId, row.action)
    }
  }

  function requestDeleteSelected() {
    if (!root.cursorActive || root.selectedIndex < 0 || root.selectedIndex >= displayModel.count) return
    var row = displayModel.get(root.selectedIndex)
    if (!row || row.kind !== "app") return
    root.deleteTarget = { appId: row.appId, label: row.label }
    deleteConfirm.selectedIndex = 1
    root.deleteConfirmOpen = true
  }

  function cancelDelete() {
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    deleteConfirm.selectedIndex = 1
    root.disarmPointer()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmDelete() {
    var target = root.deleteTarget
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    if (!target) return
    root.cancel()
    if (root.appLibrary) root.appLibrary.remove(target.appId, target.label)
  }

  function applyDmenuSelection(value) {
    applySerial = requestSerial
    opened = false
    filterText = ""
    root.finishRequest(value)
  }

  function applySelected(id, action) {
    if (!id) { cancel(); return }

    applySerial = requestSerial
    opened = false
    filterText = ""
    root.runAction(action)
  }

  function cancel() {
    if (root.dmenuActive) root.finishRequest(null)
    opened = false
    filterText = ""
  }

  function openExistingMenu(initialMenu) {
    requestSerial += 1
    mode = "menu"
    requestActive = false
    selectionFile = ""
    doneFile = ""
    activeMenu = root.item(initialMenu) ? initialMenu : "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = true
    root.disarmPointer()
    root.evaluateGuards()
    root.reloadWallpaper()
    opened = true
    enterAnim.restart()
    rebuildDisplay()
    invalidateVolatileProvider(activeMenu)
    // Third-party menus get a proxied app library whose appsChanged signal the
    // shell never emits, so the Apps rows would freeze at whatever
    // DesktopEntries held on first load. Re-pull them on every open instead.
    if (providersLoaded["apps"]) mergeAppRows()
    loadProviderForMenu(activeMenu)
    // The shell may start before first-install packages have finished placing
    // their icons. Refresh here even when the desktop entry list did not change.
    if (root.appLibrary) root.appLibrary.refreshIcons()

    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openDmenu(payload) {
    requestSerial += 1
    mode = payload.mode === "input" ? "input" : "select"
    dmenuPrompt = String(payload.prompt || (mode === "input" ? "Input" : "Select"))
    dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    selectionFile = String(payload.selectionFile || "")
    doneFile = String(payload.doneFile || "")
    requestActive = !!doneFile
    dmenuWidth = Math.max(1, Number(payload.width || 300))
    dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 0))
    activeMenu = "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = mode !== "input"
    root.disarmPointer()
    opened = true
    enterAnim.restart()
    rebuildDisplay()

    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  ListModel { id: displayModel }

  // ----------------------------------------------------------- route surface
  //
  // The menu is opened through the standard plugin lifecycle:
  // `omarchy-shell shell summon omarchy.menu '{"menu":"system"}'`.
  // Callers may pass a real id (`system`, `setup.power`) or an alias declared
  // in JSONC (`power`, `reminder-set`). Unknown strings fall through to the
  // id-as-route behavior so misspellings still attempt to open the literal id.
  function resolveRoute(input) {
    return MenuModel.resolveRoute(root.items, root.itemOrder, input)
  }

  function openRoute(initialMenu) {
    var id = root.resolveRoute(initialMenu)
    var entry = root.items[id]
    // If the resolved id is an action (i.e. the user invoked an alias for
    // a leaf, e.g. `omarchy menu summon screenrecord-stop`), run it directly
    // instead of opening an action with no children.
    if (entry && entry.kind === "action" && entry.action) {
      root.cancel()
      root.runAction(entry.action)
      return "ok"
    }
    // If it's a link (a redirect to another menu), follow the link.
    if (entry && entry.kind === "link" && entry.target) id = entry.target
    root.pendingInitialMenu = id
    root.openExistingMenu(id)
    return "ok"
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  Process {
    id: providerProc
    property string menuId: ""
    property string providerKey: ""
    property string collected: ""
    property int revision: 0
    stdout: SplitParser {
      onRead: function(data) { providerProc.collected += data + "\n" }
    }
    onExited: {
      if (providerProc.revision === root.providerRevision) {
        root.mergeProviderRows(providerProc.collected, providerProc.menuId, providerProc.providerKey)
        if (root.filterText.trim()) root.loadProvidersForSearch()
      }
      root.startNextProvider()
    }
  }

  Process {
    id: resultProc
    onExited: {
      if (root.applySerial === root.requestSerial)
        root.opened = false
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      root.reloadAppsProvider()
    }
  }

  onAppLibraryChanged: reloadAppsProvider()

  // Re-merges app rows once the library is (re)attached or its entries change.
  // Covers both an Apps menu that was already loaded and one that was opened
  // too early and came up empty.
  function reloadAppsProvider() {
    if (!root.appLibrary) return
    if (root.providersLoaded["apps"]) root.mergeAppRows()
    else if (root.opened && root.activeMenu === "apps") root.startProviderForMenu("apps")
  }

  // The JSONC sources are watched so live edits to the default file (or the
  // user extension at ~/.config/omarchy/extensions/omarchy-menu.jsonc) take
  // effect without restarting the shell.
  FileView {
    id: defaultMenuFile
    path: root.defaultMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.defaultMenuItems = root.parseMenuJsonc(text()); root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  FileView {
    id: userMenuFile
    path: root.userMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.userMenuItems = root.parseMenuJsonc(text()); root.rebuildItemsFromSources() }
    onLoadFailed: { root.userMenuItems = []; root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  // ---------------------------------------------------------------- guards
  //
  // `when:` (visibility) and `checked:` (✓ marker) are bash expressions the
  // shell wasn't allowed to evaluate before the perf rewrite. Now the shell
  // batches them into one bash subprocess per (re)load so the open path
  // never has to wait on them.

  property var whenResults: ({})       // id → true|false (allow visibility)
  property var checkedResults: ({})    // id → true|false (show ✓)
  property bool guardsPending: false

  function evaluateGuards() {
    // Process ignores a command change while it is running, and `collected`
    // belongs to the run in flight, so a second evaluation cannot overwrite
    // the first: it would throw away the lines already read and never start.
    // The surviving tail then lands as the whole answer, and every id lost
    // with it goes back to showing, since a `when:` only hides on an explicit
    // false. Wait for the run in flight and evaluate once it lands instead.
    if (guardProc.running) {
      root.guardsPending = true
      return
    }
    root.guardsPending = false

    var script = MenuModel.guardScript(root.items)
    if (!script) {
      root.whenResults = ({})
      root.checkedResults = ({})
      return
    }
    guardProc.collected = ""
    guardProc.command = ["bash", "-lc", script]
    guardProc.running = true
  }

  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { guardProc.collected += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      // A batch that was killed rather than finished has only told us about
      // the rows it reached, and a row whose `when:` went unanswered shows.
      // Keep the last complete set rather than let a half-read one through.
      // A signal leaves the exit code at 0, so the status is what tells us.
      if (exitCode !== 0 || exitStatus !== 0) {
        if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
        return
      }

      var nextWhen = ({})
      var nextChecked = ({})
      var lines = guardProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var colon = line.lastIndexOf(":")
        if (colon < 0) continue
        var value = line.substring(colon + 1) === "1"
        var rest = line.substring(0, colon)
        var tagAt = rest.lastIndexOf(":")
        if (tagAt < 0) continue
        var id = rest.substring(0, tagAt)
        var tag = rest.substring(tagAt + 1)
        if (tag === "w") nextWhen[id] = value
        else if (tag === "c") nextChecked[id] = value
      }
      root.whenResults = nextWhen
      root.checkedResults = nextChecked
      if (root.opened) root.rebuildDisplay()
      // Run the evaluation that had to stand aside. Deferred by a turn so the
      // process is settled before its command is set again.
      if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
    }
  }

  // ------------------------------------------------------- style plumbing

  FileView {
    id: styleFile
    path: root.styleFilePath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyStyleText(text())
    onLoadFailed: root.applyStyleText("")
    onFileChanged: reload()
  }

  // Cycling with Ctrl+L / Ctrl+T rewrites the file once the keys settle.
  // Written in place (not renamed over) so the file watcher stays attached.
  Timer {
    id: styleWriteDelay
    interval: 350
    onTriggered: {
      if (styleWriter.running) { restart(); return }
      var json = JSON.stringify({ layout: root.layoutId, scheme: root.schemeId, transition: root.transitionId,
                                  speed: root.transitionSpeed, animateLayouts: root.animateLayouts,
                                  animateColors: root.animateColors }, null, 2)
      styleWriter.command = ["bash", "-c", "mkdir -p \"${1%/*}\" && printf '%s\\n' \"$2\" > \"$1\"", "bash", root.styleFilePath, json]
      styleWriter.running = true
    }
  }

  Process { id: styleWriter }

  FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: root.hostName = text().trim()
  }

  Timer {
    id: toastTimer
    interval: 1400
    onTriggered: root.toastText = ""
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  property real enterProgress: 1
  NumberAnimation {
    id: enterAnim
    target: root
    property: "enterProgress"
    from: 0
    to: 1
    duration: Math.max(1, Math.round((root.customTransition ? root.transitionDef.ms || 200 : 190) / root.speedFactor))
    easing.type: root.customTransition ? (root.easings[root.transitionDef.ease] || Easing.OutCubic) : Easing.OutCubic
  }

  SequentialAnimation {
    id: morphAnim
    NumberAnimation { target: root; property: "morphProgress"; from: 0; to: 1; duration: root.morphMs; easing.type: Easing.OutCubic }
    ScriptAction { script: root.morphing = false }
  }

  // ------------------------------------------------- shared view components

  // App icon, Nerd Font glyph, or a lettered fallback. `tile` paints a
  // rounded plate behind glyphs so they sit level with real app icons.
  component ItemIcon: Item {
    id: icon
    property var host: null
    property string kind: ""
    property string glyph: ""
    property string glyphFont: ""
    property string appIcon: ""
    property string label: ""
    property real size: Style.space(24)
    property bool tile: false
    property color tint: host.foreground
    readonly property bool isApp: kind === "app"

    width: size
    height: size

    Rectangle {
      anchors.fill: parent
      visible: icon.tile && !icon.isApp
      radius: icon.size * 0.26
      color: host.surfaceAlt
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(host.accent, 0.35)
    }

    Image {
      anchors.fill: parent
      visible: icon.isApp
      source: icon.isApp && host.appLibrary ? host.appLibrary.iconSource(icon.appIcon) : ""
      sourceSize.width: icon.size * Screen.devicePixelRatio
      sourceSize.height: icon.size * Screen.devicePixelRatio
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
    }

    Text {
      visible: !icon.isApp
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: icon.glyph.length > 0 ? icon.glyph : (icon.label ? icon.label.charAt(0).toUpperCase() : "•")
      color: icon.tile ? host.glyphAccent : icon.tint
      font.family: icon.glyphFont.length > 0 ? icon.glyphFont : host.fontFamily
      font.pixelSize: Math.round(icon.size * (icon.tile ? 0.5 : (icon.glyph.length > 0 ? 0.86 : 0.6)))
      font.weight: icon.glyph.length > 0 ? Font.Normal : Font.Bold
    }
  }

  // rofi-style input: an accent prompt badge (doubling as a back button in
  // submenus) followed by the query, a caret, and an optional key hint.
  component SearchBar: Rectangle {
    id: bar
    property var host: null
    property bool showHint: false

    height: host.searchHeight
    radius: host.searchIsPill ? height / 2 : Math.max(0, host.itemRadius)
    color: host.surfaceAlt

    Rectangle {
      id: prompt
      anchors.left: parent.left
      anchors.leftMargin: Style.space(5)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height - Style.space(10)
      width: promptRow.implicitWidth + Style.space(26)
      radius: Math.max(0, bar.radius - Style.space(5))
      color: host.accent

      Row {
        id: promptRow
        anchors.centerIn: parent
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: host.promptGlyph()
          color: host.accentText
          font.family: host.fontFamily
          font.pixelSize: Style.font.heading
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          textFormat: Text.PlainText
          text: host.promptLabel()
          color: host.accentText
          font.family: host.fontFamily
          font.pixelSize: Style.font.body
          font.weight: Font.Bold
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: !host.dmenuActive && host.activeMenu !== "root"
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: host.goBack()
      }
    }

    Row {
      anchors.left: prompt.right
      anchors.leftMargin: Style.space(12)
      anchors.right: hint.visible ? hint.left : parent.right
      anchors.rightMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)
      clip: true

      Text {
        textFormat: Text.PlainText
        visible: host.filterText.length > 0
        text: host.filterText
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.heading
      }

      Rectangle {
        width: Math.max(1, Style.space(2))
        height: Style.font.heading + Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
        color: host.accent
        SequentialAnimation on opacity {
          running: host.opened
          loops: Animation.Infinite
          NumberAnimation { to: 0; duration: 530; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 530; easing.type: Easing.InOutSine }
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: host.filterText.length === 0
        text: host.dmenuActive ? "" : (host.layoutKind === "grid" || host.activeMenu === "apps" ? "Type to search…" : "Search…")
        color: host.foreground
        opacity: 0.45
        font.family: host.fontFamily
        font.pixelSize: Style.font.heading
      }
    }

    Text {
      id: hint
      visible: bar.showHint && bar.width > Style.space(460)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(16)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "Ctrl+L layout · Ctrl+T colors"
      color: host.foreground
      opacity: 0.4
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component ListRow: Item {
    id: lrow
    property var host: null
    required property int index
    required property string itemId
    required property string kind
    required property string icon
    required property string iconFont
    required property string appIcon
    required property string appId
    required property string label
    required property string detail
    readonly property bool hasCursor: host.cursorActive && lrow.index === host.selectedIndex
    readonly property bool submenu: lrow.kind === "menu" || lrow.kind === "link"

    width: ListView.view ? ListView.view.width : 0
    height: host.listRowHeight(lrow.detail)

    Rectangle {
      anchors.fill: parent
      radius: host.itemRadius
      color: lrow.hasCursor ? host.selectedBackground : "transparent"
      Behavior on color { ColorAnimation { duration: 90 } }
    }

    Rectangle {
      visible: lrow.hasCursor && host.effectiveLayout === "sidebar"
      width: Style.space(3)
      height: parent.height * 0.5
      radius: width / 2
      color: host.selectedText
      x: host.onRight ? parent.width - width - Style.space(4) : Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
    }

    ItemIcon {

      host: lrow.host
      id: rowIcon
      anchors.left: parent.left
      anchors.leftMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      size: host.listIconSize
      kind: lrow.kind
      glyph: lrow.icon
      glyphFont: lrow.iconFont
      appIcon: lrow.appIcon
      label: lrow.label
      tint: lrow.hasCursor ? host.selectedText : host.foreground
    }

    Column {
      anchors.left: rowIcon.right
      anchors.leftMargin: Style.space(12)
      anchors.right: chevron.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: lrow.label
        color: lrow.hasCursor ? host.selectedText : host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.heading
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: host.showsDetails(lrow.detail)
        textFormat: Text.PlainText
        text: lrow.detail
        color: lrow.hasCursor ? host.selectedText : host.foreground
        opacity: 0.6
        font.family: host.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }

    Text {
      id: chevron
      anchors.right: parent.right
      anchors.rightMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: lrow.submenu ? "›" : ""
      color: lrow.hasCursor ? host.selectedText : host.foreground
      opacity: 0.5
      font.family: host.fontFamily
      font.pixelSize: Style.font.heading
    }

    MouseArea {
      id: lrowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      preventStealing: lrow.kind === "app"
      onEntered: host.selectFromPointer(lrow.index, lrow, { x: lrowMouse.mouseX, y: lrowMouse.mouseY })
      onPressed: function(mouse) { host.appDragPress(lrow.kind, lrow.appId, lrow.appIcon, lrow.label, lrow, mouse) }
      onReleased: host.appDragRelease()
      onPositionChanged: function(mouse) { if (!host.appDragMove(lrow, mouse)) host.selectFromPointer(lrow.index, lrow, mouse) }
      onClicked: {
        if (host.appDragSuppressClick) return
        host.cursorActive = true
        host.selectedIndex = lrow.index
        host.activateIndex(lrow.index, true)
      }
    }
  }

  // Icon above a centered label, for the launchpad, grid, and dock.
  component IconCell: Item {
    id: cell
    property var host: null
    required property int index
    required property string kind
    required property string icon
    required property string iconFont
    required property string appIcon
    required property string appId
    required property string label
    property real iconSize: host.gridIconSize
    property bool translucent: false
    readonly property bool hasCursor: host.cursorActive && cell.index === host.selectedIndex

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(5)
      radius: host.itemRadius + Style.space(4)
      color: cell.hasCursor ? Util.alpha(host.selectedBackground, cell.translucent ? 0.42 : 1) : "transparent"
      border.width: cell.hasCursor && cell.translucent ? Math.max(1, Style.space(1)) : 0
      border.color: Util.alpha(host.selectedBackground, 0.9)
      Behavior on color { ColorAnimation { duration: 90 } }
    }

    Column {
      anchors.centerIn: parent
      width: parent.width - Style.space(16)
      spacing: Style.space(8)
      scale: cell.hasCursor ? 1.06 : 1
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      ItemIcon {

        host: cell.host
        anchors.horizontalCenter: parent.horizontalCenter
        size: cell.iconSize
        tile: true
        kind: cell.kind
        glyph: cell.icon
        glyphFont: cell.iconFont
        appIcon: cell.appIcon
        label: cell.label
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: cell.label + (cell.kind === "menu" || cell.kind === "link" ? " ›" : "")
        color: cell.hasCursor && !cell.translucent ? host.selectedText : host.foreground
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: host.fontFamily
        font.pixelSize: host.effectiveLayout === "launchpad" ? Style.font.body : Style.font.bodySmall
        font.weight: cell.hasCursor ? Font.DemiBold : Font.Normal
      }
    }

    MouseArea {
      id: cellMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      preventStealing: cell.kind === "app"
      onEntered: host.selectFromPointer(cell.index, cell, { x: cellMouse.mouseX, y: cellMouse.mouseY })
      onPressed: function(mouse) { host.appDragPress(cell.kind, cell.appId, cell.appIcon, cell.label, cell, mouse) }
      onReleased: host.appDragRelease()
      onPositionChanged: function(mouse) { if (!host.appDragMove(cell, mouse)) host.selectFromPointer(cell.index, cell, mouse) }
      onClicked: {
        if (host.appDragSuppressClick) return
        host.cursorActive = true
        host.selectedIndex = cell.index
        host.activateIndex(cell.index, true)
      }
    }
  }

  // Compact glyph + label chip for the dmenu-style top bar.
  component Chip: Item {
    id: chip
    property var host: null
    required property int index
    required property string kind
    required property string icon
    required property string iconFont
    required property string appIcon
    required property string appId
    required property string label
    readonly property bool hasCursor: host.cursorActive && chip.index === host.selectedIndex

    width: chipRow.implicitWidth + Style.space(24)
    height: ListView.view ? ListView.view.height : 0

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.space(2)
      anchors.bottomMargin: Style.space(2)
      radius: host.itemRadius
      color: chip.hasCursor ? host.selectedBackground : "transparent"
    }

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: Style.space(8)

      ItemIcon {

        host: chip.host
        anchors.verticalCenter: parent.verticalCenter
        size: Style.space(18)
        kind: chip.kind
        glyph: chip.icon
        glyphFont: chip.iconFont
        appIcon: chip.appIcon
        label: chip.label
        tint: chip.hasCursor ? host.selectedText : host.foreground
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: chip.label + (chip.kind === "menu" || chip.kind === "link" ? " ›" : "")
        color: chip.hasCursor ? host.selectedText : host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.body
        font.weight: chip.hasCursor ? Font.DemiBold : Font.Normal
      }
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      preventStealing: chip.kind === "app"
      onEntered: host.selectFromPointer(chip.index, chip, { x: chipMouse.mouseX, y: chipMouse.mouseY })
      onPressed: function(mouse) { host.appDragPress(chip.kind, chip.appId, chip.appIcon, chip.label, chip, mouse) }
      onReleased: host.appDragRelease()
      onPositionChanged: function(mouse) { if (!host.appDragMove(chip, mouse)) host.selectFromPointer(chip.index, chip, mouse) }
      onClicked: {
        if (host.appDragSuppressClick) return
        host.cursorActive = true
        host.selectedIndex = chip.index
        host.activateIndex(chip.index, true)
      }
    }
  }

  // Wallpaper clipped to a rounded rectangle, with an optional blur.
  component Wallpaper: Item {
    id: wall
    property var host: null
    property real radius: 0
    property real blur: 0

    Image {
      id: wallImage
      anchors.fill: parent
      visible: false
      source: host.wallpaperSource
      cache: false
      asynchronous: true
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: Math.min(1920, wall.width * Screen.devicePixelRatio)
    }

    Item {
      id: wallMask
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle { anchors.fill: parent; radius: wall.radius; color: "black" }
    }

    MultiEffect {
      anchors.fill: parent
      source: wallImage
      visible: wallImage.status === Image.Ready
      maskEnabled: wall.radius > 0
      maskSource: wallMask
      blurEnabled: wall.blur > 0
      blur: wall.blur
      blurMax: 64
      autoPaddingEnabled: false
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened && root.rowsLoaded
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // The card opens centered exactly as always. The first search keystroke
    // or submenu move freezes the top line where it currently sits — from
    // then on the card grows and shrinks downward instead of re-centering
    // on every resize, which made the menu jump around. The rows height is
    // frozen at the same moment, so the starting menu also caps how tall the
    // card may grow from there. Closing unfreezes both.
    property int cardTop: -1
    property int maxRowsHeight: -1
    readonly property int centeredTop: Math.max(Style.gapsOut, Math.round((height - root.cardHeight) / 2))
    readonly property int effectiveCardTop: cardTop >= 0 ? cardTop : centeredTop
    function freezeCardTop() {
      if (visible && cardTop < 0) {
        cardTop = effectiveCardTop
        maxRowsHeight = root.visibleRowsHeight
      }
    }
    onVisibleChanged: if (!visible) { cardTop = -1; maxRowsHeight = -1 }

    readonly property bool classic: root.layoutKind === "classic"
    readonly property var paddings: ({ topbar: 6, launchpad: 0, sidebar: 14, dock: 14 })
    readonly property int modernPadding: Style.space(paddings[root.effectiveLayout] !== undefined ? paddings[root.effectiveLayout] : 16)

    // Card placement for the non-classic layouts.
    readonly property var modernRect: {
      var pw = panel.width
      var ph = panel.height
      var g = Style.gapsOut
      var pad = panel.modernPadding * 2 + Style.space(4)
      var w = 0
      var h = 0
      var def = root.layoutDef
      // An anchor moves a card to a corner or an edge ("top-left", "bottom",
      // "right"…), inset from it; "center" or none leaves it where its
      // layout puts it.
      var anchor = String(def.anchor || "")
      var anchored = anchor !== "" && anchor !== "center"
      var edgeGap = anchored ? Math.max(g, Style.space(def.inset !== undefined ? def.inset : 20)) : g
      // A preset's own size, in logical px, clamped to the screen; "full"
      // takes all the room there is.
      function size(key, fallback, room) { return def[key] === "full" ? room : Math.min(Style.space(def[key] || fallback), room) }
      function place(r) {
        if (!anchored) return r
        var x = anchor.indexOf("left") >= 0 ? edgeGap : anchor.indexOf("right") >= 0 ? pw - r.w - edgeGap : Math.round((pw - r.w) / 2)
        var y = anchor.indexOf("top") >= 0 ? edgeGap : anchor.indexOf("bottom") >= 0 ? ph - r.h - edgeGap : Math.round((ph - r.h) / 2)
        return { x: x, y: y, w: r.w, h: r.h }
      }
      switch (root.effectiveLayout) {
      case "sidebar":
        if (def.floating) {
          var inset = Style.space(20)
          w = size("width", 380, pw - inset * 2)
          h = size("height", 720, ph - inset * 2)
          return { x: root.onRight ? pw - w - inset : inset, y: Math.round((ph - h) / 2), w: w, h: h }
        }
        w = size("width", 400, pw - g * 2)
        return { x: root.onRight ? pw - w - g : g, y: g, w: w, h: ph - g * 2 }
      case "spotlight":
        w = size("width", 700, pw - edgeGap * 2)
        var centered = def.top === "center"
        var top = centered ? g : Math.round(ph * (Number(def.top) || 0.16))
        var rows = Math.max(root.listRowBase, Math.min(modernList.contentHeight, Style.space(520)))
        h = Math.min(anchored ? ph - edgeGap * 2 : ph - top - g, pad + root.searchHeight + root.contentSpacing * 2 + rows)
        return place({ x: Math.round((pw - w) / 2), y: centered ? Math.round((ph - h) / 2) : top, w: w, h: h })
      case "split":
        w = size("width", 900, pw - edgeGap * 2)
        h = size("height", 540, ph - edgeGap * 2)
        return place({ x: Math.round((pw - w) / 2), y: Math.round((ph - h) / 2), w: w, h: h })
      case "launchpad":
        return { x: 0, y: 0, w: pw, h: ph }
      case "grid":
        w = size("width", 860, pw - edgeGap * 2)
        h = size("height", 600, ph - edgeGap * 2)
        return place({ x: Math.round((pw - w) / 2), y: Math.round((ph - h) / 2), w: w, h: h })
      case "dock":
        w = Math.max(Style.space(560), Math.min(pw - Style.space(80), displayModel.count * root.dockCell + pad))
        h = pad + root.searchHeight + root.contentSpacing * 2 + root.dockCell + Style.space(18)
        return { x: Math.round((pw - w) / 2), y: root.atTop ? Style.space(28) : ph - h - Style.space(28), w: w, h: h }
      case "topbar":
        h = root.searchHeight + pad
        return { x: g, y: root.atBottom ? ph - h - g : g, w: pw - g * 2, h: h }
      }
      return { x: 0, y: 0, w: 0, h: 0 }
    }

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      visible: root.effectiveLayout !== "launchpad"
      opacity: root.appDrag ? 0 : 1
    }

    // Launchpad backdrop: the wallpaper, blurred, under a tint of the scheme.
    Item {
      anchors.fill: parent
      visible: root.effectiveLayout === "launchpad"
      opacity: root.appDrag ? 0 : root.enterProgress

      Wallpaper {
        anchors.fill: parent
        host: root
        blur: 1
      }

      Rectangle {
        anchors.fill: parent
        color: Util.alpha(root.background, 0.6)
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }

    BorderSurface {
      id: card
      Behavior on x { enabled: root.morphing; NumberAnimation { duration: root.morphMs; easing.type: Easing.OutCubic } }
      Behavior on y { enabled: root.morphing; NumberAnimation { duration: root.morphMs; easing.type: Easing.OutCubic } }
      Behavior on width { enabled: root.morphing; NumberAnimation { duration: root.morphMs; easing.type: Easing.OutCubic } }
      Behavior on height { enabled: root.morphing; NumberAnimation { duration: root.morphMs; easing.type: Easing.OutCubic } }
      x: panel.classic ? Math.round((panel.width - width) / 2) : panel.modernRect.x
      y: panel.classic ? panel.effectiveCardTop : panel.modernRect.y
      width: panel.classic ? root.cardWidth : panel.modernRect.w
      height: panel.classic ? Math.min(root.cardHeight, panel.height - Style.gapsOut - panel.effectiveCardTop) : panel.modernRect.h
      radius: panel.classic ? root.cornerRadius : (root.effectiveLayout === "launchpad" ? 0 : root.layoutRadius)
      color: root.effectiveLayout === "launchpad" ? "transparent" : root.background
      borderSpec: root.effectiveLayout === "launchpad" ? Border.none() : root.borderSpec
      padding: panel.classic ? root.contentMargin : panel.modernPadding

      // "Layout's own" entrance: slide in from the docked edge, or settle
      // from slightly smaller. A chosen transition replaces it for every
      // layout (Styles.transitions describes each one's start).
      readonly property real enterGap: 1 - root.enterProgress
      readonly property var tdef: root.transitionDef
      readonly property bool custom: root.customTransition
      readonly property real fadeIn: tdef.id === "none" ? 1 : Math.max(0, Math.min(1, root.enterProgress * 1.6))
      // Nearly gone while an app is dragged out, so the dock shows through.
      opacity: (custom ? fadeIn : (panel.classic ? 1 : root.enterProgress)) * (root.appDrag ? 0.12 : 1) * root.morphOpacity
      transform: [
        Translate {
          x: card.custom ? card.enterGap * (card.tdef.x || 0) * (card.width + Style.space(160))
            : (root.effectiveLayout === "sidebar" ? (root.onRight ? 1 : -1) * card.enterGap * Style.space(40) : 0)
          y: card.custom ? card.enterGap * (card.tdef.y || 0) * (card.height + Style.space(160))
            : (root.effectiveLayout === "dock" ? (root.atTop ? -1 : 1) * card.enterGap * Style.space(40)
            : (root.effectiveLayout === "topbar" ? (root.atBottom ? 1 : -1) * card.enterGap * Style.space(24) : 0))
        },
        Scale {
          readonly property bool grows: !panel.classic && ["sidebar", "dock", "topbar"].indexOf(root.effectiveLayout) < 0
          readonly property real from: card.tdef.scale !== undefined ? card.tdef.scale : 1
          readonly property real fromY: card.tdef.yScale !== undefined ? card.tdef.yScale : from
          origin.x: card.width / 2
          origin.y: card.height / 2
          xScale: (card.custom ? from + (1 - from) * root.enterProgress
            : (grows ? 0.965 + 0.035 * root.enterProgress : 1)) * root.morphScale
          yScale: (card.custom ? fromY + (1 - fromY) * root.enterProgress
            : (grows ? 0.965 + 0.035 * root.enterProgress : 1)) * root.morphScale
        },
        Rotation {
          readonly property string around: card.tdef.axis || "z"
          // Swing hinges on the top edge; flip and spin turn about the middle.
          origin.x: card.width / 2
          origin.y: around === "x" ? 0 : card.height / 2
          axis { x: around === "x" ? 1 : 0; y: around === "y" ? 1 : 0; z: around === "z" ? 1 : 0 }
          angle: card.custom ? (card.tdef.angle || 0) * card.enterGap : 0
        }
      ]

      MouseArea { anchors.fill: parent; onClicked: root.effectiveLayout === "launchpad" ? root.cancel() : undefined }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.deleteConfirmOpen ? 20 : 0
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.deleteConfirmOpen) {
            if (deleteConfirm.handleKey(event)) event.accepted = true
            return
          }

          if (event.key === Qt.Key_Delete) {
            root.requestDeleteSelected()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.cancel()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_L || event.key === Qt.Key_T)) {
            var step = (event.modifiers & Qt.ShiftModifier) ? -1 : 1
            if (event.key === Qt.Key_L) root.cycleLayout(step)
            else root.cycleScheme(step)
            event.accepted = true
          } else if ((root.layoutKind === "grid" || root.layoutKind === "strip") && root.handleSpatialKey(event)) {
            event.accepted = true
          } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (root.layoutKind === "grid") root.moveGrid(event.key === Qt.Key_Tab ? 1 : -1, 0)
            else root.select(event.key === Qt.Key_Tab ? 1 : -1)
            event.accepted = true
          } else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) && !root.filterText) {
            root.goBack()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
            if (root.dmenuActive) {
              if (root.mode === "input") root.applyDmenuSelection(root.filterText)
              else if (displayModel.count > 0) root.activateIndex(root.cursorActive ? root.selectedIndex : 0)
            } else if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0) root.cursorActive = true
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: deleteConfirm

          anchors.fill: parent
          opened: root.deleteConfirmOpen
          z: 10
          message: "Do you want to uninstall " + ((root.deleteTarget && root.deleteTarget.label) || "") + "?"
          confirmText: "Uninstall"
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelDelete()
          onConfirmed: root.confirmDelete()
        }
      }

      Column {
        visible: panel.classic
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || (root.dmenuActive ? (root.dmenuPrompt + "…") : ((root.item(root.activeMenu) ? (root.item(root.activeMenu).title || root.item(root.activeMenu).label) : "Go") + "…"))
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

        }

        Item {
          width: parent.width
          height: root.visibleRowsHeight

          ListView {
            id: resultList
            anchors.fill: parent
            model: panel.classic ? displayModel : null
            clip: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            section.property: "section"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
              required property string section

              width: ListView.view.width
              height: section === "drilldown" ? root.dividerHeight : 0
              visible: section === "drilldown"

              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(4)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.spacing.hairline
                color: Util.alpha(root.foreground, 0.2)
              }
            }

            delegate: BorderSurface {
              id: row
              required property int index
              required property string itemId
              required property string kind
              required property string icon
              required property string iconFont
              required property string appIcon
              required property string appId
              required property string label
              required property string target
              required property string detail
              required property string path
              required property string action
              required property int childCount

              readonly property bool hasCursor: root.cursorActive && row.index === root.selectedIndex
              readonly property bool isApp: row.kind === "app"
              readonly property bool hasIcon: row.icon.length > 0 || row.isApp

              width: ListView.view.width
              height: root.rowHeightForDetail(row.detail)
              radius: root.cornerRadius
              color: row.hasCursor ? root.selectedBackground : "transparent"
              borderSpec: row.hasCursor ? root.selectedBorderSpec : Border.none()

              Rectangle {
                visible: false
                width: Style.space(4)
                height: parent.height - Style.space(18)
                radius: Math.min(root.cornerRadius, Style.space(4))
                color: root.selectedBackground
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: iconText
                textFormat: Text.PlainText
                visible: row.hasIcon && !row.isApp
                text: row.icon
                color: row.hasCursor ? root.selectedText : root.foreground
                font.family: row.iconFont.length > 0 ? row.iconFont : root.fontFamily
                font.pixelSize: Style.font.iconLarge
                width: Style.space(36)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
              }

              Image {
                id: appIconImage
                visible: row.isApp
                width: Style.font.iconLarge
                height: Style.font.iconLarge
                fillMode: Image.PreserveAspectFit
                // Decode at physical pixels — a logical-size decode leaves
                // PNG icons upscaled and blurry on HiDPI displays.
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                source: row.isApp && root.appLibrary ? root.appLibrary.iconSource(row.appIcon) : ""
                asynchronous: true
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8) + (Style.space(36) - width) / 2
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
              }

              Column {
                id: contentColumn
                anchors.left: row.hasIcon ? iconText.right : parent.left
                anchors.leftMargin: row.hasIcon ? Style.space(6) : root.rowReservedBorderLeft + Style.space(18)
                anchors.right: trail.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  id: labelText
                  textFormat: Text.PlainText
                  width: parent.width
                  text: row.label
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                  font.weight: Font.Medium
                  elide: Text.ElideRight
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: row.detail
                  visible: (root.filterText || row.kind === "dmenu") && row.detail.length > 0
                  color: root.foreground
                  opacity: 0.52
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              Row {
                id: trail
                width: Style.space(14)
                anchors.right: parent.right
                anchors.rightMargin: root.rowReservedBorderRight + Style.space(8)
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
                spacing: 0

                Text {
                  textFormat: Text.PlainText
                  visible: false
                  text: row.childCount
                  color: root.foreground
                  opacity: 0.45
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  textFormat: Text.PlainText
                  text: row.kind === "menu" || row.kind === "link" ? "›" : ""
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: row.kind === "menu" || row.kind === "link" ? 0.36 : 0
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                  font.weight: Font.Normal
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: row.isApp
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectFromPointer(row.index, row, {
                  x: mouseArea.mouseX,
                  y: mouseArea.mouseY
                })
                onPressed: function(mouse) { root.appDragPress(row.kind, row.appId, row.appIcon, row.label, row, mouse) }
                onReleased: root.appDragRelease()
                onPositionChanged: function(mouse) {
                  if (root.appDragMove(row, mouse)) return
                  root.selectFromPointer(row.index, row, mouse)
                }
                onClicked: {
                  if (root.appDragSuppressClick) return
                  root.cursorActive = true
                  root.selectedIndex = row.index
                  root.activateIndex(row.index, true)
                }
              }
            }
          }

          // Scroll scrims. The clipped row already marks the fold at rest;
          // these keep both edges honest once the list has been scrolled,
          // when content hides above the card top as well as below. Strength
          // tracks the distance still hidden past each edge rather than
          // animating on a clock, so a programmatic jump — wrapping from the
          // last row back to the first — lands with the fade already applied.
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.contentY - resultList.originY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: root.background }
              GradientStop { position: 1; color: Util.alpha(root.background, 0) }
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.originY + resultList.contentHeight - resultList.height - resultList.contentY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: Util.alpha(root.background, 0) }
              GradientStop { position: 1; color: root.background }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0 && root.mode !== "input"

            Text {
              text: "󰈉"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: Style.space(320)
            }

            Text {
              textFormat: Text.PlainText
              text: root.filterText ? "No matches for “" + root.filterText + "”" : "Nothing here yet"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: Style.space(320)
            }
          }
        }

        Item {
          width: parent.width
          height: 0
        }
      }

      // ------------------------------------------------ styled layouts

      Item {
        id: modern
        visible: !panel.classic
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        readonly property string layout: root.effectiveLayout

        // Sidebar: wallpaper banner with the time and user@host.
        Item {
          id: banner
          visible: modern.layout === "sidebar"
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: visible ? Style.space(150) : 0

          Wallpaper {
            anchors.fill: parent
            host: root
            radius: root.itemRadius
          }

          Rectangle {
            anchors.fill: parent
            radius: root.itemRadius
            gradient: Gradient {
              GradientStop { position: 0.3; color: Util.alpha(root.background, 0) }
              GradientStop { position: 1; color: Util.alpha(root.background, 0.88) }
            }
          }

          Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(14)
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: Qt.formatDateTime(clock.date, "HH:mm")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.weight: Font.Bold
            }

            Text {
              textFormat: Text.PlainText
              text: Quickshell.env("USER") + (root.hostName ? "@" + root.hostName : "")
              color: root.foreground
              opacity: 0.75
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }
        }

        // Split: wallpaper pane previewing the item under the cursor.
        Item {
          id: hero
          visible: modern.layout === "split"
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: visible ? Math.round(parent.width * 0.4) : 0

          Wallpaper {
            anchors.fill: parent
            host: root
            radius: root.itemRadius
          }

          Rectangle {
            anchors.fill: parent
            radius: root.itemRadius
            gradient: Gradient {
              GradientStop { position: 0; color: Util.alpha(root.background, 0.15) }
              GradientStop { position: 0.55; color: Util.alpha(root.background, 0.35) }
              GradientStop { position: 1; color: Util.alpha(root.background, 0.92) }
            }
          }

          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Style.space(20)
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: Qt.formatDateTime(clock.date, "HH:mm")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.weight: Font.Bold
            }

            Text {
              textFormat: Text.PlainText
              text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
              color: root.foreground
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          Column {
            visible: root.currentRow !== null
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(20)
            spacing: Style.space(10)

            ItemIcon {
              host: root
              size: Style.space(64)
              tile: true
              kind: root.currentRow ? root.currentRow.kind : ""
              glyph: root.currentRow ? root.currentRow.icon : ""
              glyphFont: root.currentRow ? root.currentRow.iconFont : ""
              appIcon: root.currentRow ? root.currentRow.appIcon : ""
              label: root.currentRow ? root.currentRow.label : ""
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.currentRow ? root.currentRow.label : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.weight: Font.Bold
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.currentRow ? (root.currentRow.detail || root.currentRow.path || "") : ""
              visible: text.length > 0
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
            }
          }
        }

        SearchBar {
          id: search
          host: root
          showHint: ["spotlight", "split", "grid", "launchpad"].indexOf(modern.layout) >= 0
          readonly property real barLeft: modern.layout === "split" ? hero.width + Style.space(16) : 0
          readonly property real barSpan: modern.layout === "launchpad" ? Math.min(Style.space(600), modern.width - Style.space(40))
            : (modern.layout === "topbar" ? Math.min(Style.space(440), Math.round(modern.width * 0.32)) : modern.width - barLeft)
          x: modern.layout === "launchpad" ? Math.round((modern.width - barSpan) / 2) : barLeft
          y: modern.layout === "launchpad" ? Style.space(72)
            : (modern.layout === "sidebar" ? banner.height + Style.space(12)
            : (modern.layout === "topbar" ? Math.round((modern.height - height) / 2) : 0))
          width: barSpan
        }

        Item {
          id: body
          x: modern.layout === "topbar" ? search.x + search.width + Style.space(10)
            : (modern.layout === "launchpad" ? 0 : search.x)
          y: modern.layout === "topbar" ? 0 : search.y + search.height + root.contentSpacing * 2
          width: parent.width - x
          height: parent.height - y - (modern.layout === "launchpad" ? Style.space(64) : 0)

          ListView {
            id: modernList
            anchors.fill: parent
            visible: root.layoutKind === "list"
            model: visible ? displayModel : null
            spacing: Style.space(3)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: ListRow { host: root }
          }

          GridView {
            id: iconGrid
            visible: root.layoutKind === "grid"
            model: visible ? displayModel : null
            readonly property real targetCell: Style.space(modern.layout === "launchpad" ? 170 : 150)
            readonly property real usable: body.width - (modern.layout === "launchpad" ? Style.space(120) : 0)
            readonly property int columns: Math.max(1, Math.min(modern.layout === "launchpad" ? 8 : (root.layoutDef.columns || 6), Math.floor(usable / targetCell)))
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: modern.layout === "launchpad" ? columns * targetCell : body.width
            cellWidth: Math.floor(width / columns)
            cellHeight: root.gridCellHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: IconCell {
              host: root
              width: GridView.view.cellWidth
              height: GridView.view.cellHeight
              translucent: modern.layout === "launchpad"
            }
          }

          ListView {
            id: stripList
            visible: root.layoutKind === "strip"
            model: visible ? displayModel : null
            orientation: ListView.Horizontal
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            // The dock hugs its icons; the top bar runs the full width.
            width: modern.layout === "dock" ? Math.min(parent.width, Math.max(contentWidth, 1)) : parent.width
            spacing: modern.layout === "topbar" ? Style.space(4) : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: modern.layout === "topbar" ? chipDelegate : dockDelegate
          }

          Component {
            id: chipDelegate
            Chip { host: root }
          }

          Component {
            id: dockDelegate
            IconCell {
              host: root
              width: root.dockCell
              height: root.dockCell + Style.space(18)
              iconSize: root.dockIconSize
            }
          }

          Text {
            anchors.centerIn: parent
            visible: displayModel.count === 0 && root.mode !== "input"
            textFormat: Text.PlainText
            text: root.filterText ? "No matches for “" + root.filterText + "”" : "Nothing here yet"
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: modern.layout === "topbar" ? Style.font.body : Style.font.title
          }
        }

        Text {
          visible: modern.layout === "launchpad"
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(24)
          textFormat: Text.PlainText
          text: "↵ open   ⌫ back   Esc close   Ctrl+L layout   Ctrl+T colors"
          color: root.foreground
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // Names the new layout or scheme while cycling with Ctrl+L / Ctrl+T.
    Rectangle {
      visible: root.toastText.length > 0
      z: 50
      anchors.horizontalCenter: parent.horizontalCenter
      y: (root.effectiveLayout === "dock" && !root.atTop) || (root.effectiveLayout === "topbar" && root.atBottom)
        ? Style.space(80) : parent.height - height - Style.space(80)
      width: toastLabel.implicitWidth + Style.space(36)
      height: toastLabel.implicitHeight + Style.space(18)
      radius: height / 2
      color: root.accent

      Text {
        id: toastLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.toastText
        color: root.accentText
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.weight: Font.Bold
      }
    }

    // Icon that follows the pointer while an app is dragged to the dock.
    Item {
      visible: root.appDrag !== null
      x: root.appDragPos.x - width / 2
      y: root.appDragPos.y - height / 2
      width: Style.space(48)
      height: Style.space(48)
      z: 1000

      Rectangle {
        anchors.fill: parent
        anchors.margins: -Style.space(6)
        radius: Style.space(12)
        color: Util.alpha(root.background, 0.85)
        border.width: 1
        border.color: Util.alpha(root.foreground, 0.25)
      }

      ItemIcon {
        host: root
        anchors.fill: parent
        size: Style.space(48)
        tile: true
        kind: "app"
        appIcon: root.appDrag ? root.appDrag.appIcon : ""
        label: root.appDrag ? root.appDrag.label : ""
      }
    }
  }
}

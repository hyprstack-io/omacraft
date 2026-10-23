import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "WallPickerModel.js" as Model

// OmaCraft's wallpaper picker: Omarchy's background switcher (the slanted
// slices of omarchy.image-picker) with OmaCraft's wallpapers behind it, in
// four tabs: the theme's backgrounds, a Wallhaven search, the downloaded
// library and the favourites. It reads and writes everything through the
// Studio plugin's hyprskin, exactly as OmaCraft's Wallpapers page does, so both
// show the same search, library and hearts, and picking one sets it with
// `hyprskin apply`: the wallpaper, and, while wallpaper colours are on, the
// theme built from it for the rest of Omarchy. OmaCraft's own window never
// opens.
//
//   omarchy-shell shell toggle omacraft.wallpicker '{"tab":"wallhaven"}'
Item {
  id: root

  // Injected by omarchy-shell.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property var shell: null
  property var manifest: null
  readonly property string pluginId: (root.manifest && root.manifest.id) || "omacraft.wallpicker"

  readonly property string home: Quickshell.env("HOME")
  readonly property string hyprskin: Quickshell.env("OMACRAFT_HYPRSKIN") || (home + "/.config/omarchy/plugins/omacraft.studio/bin/hyprskin")
  readonly property string stateHome: home + "/.local/state"

  property bool opened: false

  readonly property var tabs: [
    { id: "theme", label: "Theme" },
    { id: "wallhaven", label: "Search Wallhaven" },
    { id: "library", label: "Library" },
    { id: "favorites", label: "Favorites" }
  ]
  property string tab: "theme"
  readonly property int tabIndex: tabIds().indexOf(tab)

  property var status: ({})
  readonly property string current: String(status.current || "")
  readonly property var savedSearch: (status.settings && status.settings.search) || ({})
  readonly property string libraryDir: expandHome(String((status.settings && status.settings.library) || "~/Pictures/Wallhaven"))

  // Each tab's wallpapers, as Model entries.
  property var themeList: []
  property var searchList: []
  property var libraryList: []
  property var favoriteList: []
  property var libraryFiles: []
  property var favoritesRaw: []
  property var thumbs: ({})

  readonly property var entries: tab === "wallhaven" ? searchList
    : tab === "library" ? libraryList
    : tab === "favorites" ? favoriteList
    : themeList

  // The typed line filters the other tabs and is the query on Wallhaven.
  property string filterText: ""
  property string query: ""
  property string searchedQuery: ""
  property bool searchStarted: false
  property string seed: ""
  property int searchPage: 0
  property int searchLastPage: 1
  property int searchTotal: 0
  property string error: ""
  readonly property string typed: tab === "wallhaven" ? query : filterText
  readonly property bool moreResults: searchStarted && searchList.length > 0 && searchPage < searchLastPage && searchPage < 40

  property int selectedIndex: 0
  property var selectedByTab: ({})
  // The expanded card swaps its small preview for the full picture once the
  // selection has rested on it, so browsing never downloads every wallpaper.
  property bool selectionSettled: false

  readonly property var favoriteKeys: {
    var keys = {}
    for (var i = 0; i < favoritesRaw.length; i++) keys[favoritesRaw[i].key] = true
    return keys
  }

  property color dimColor: Commons.Color.background
  // The wallpaper's accent, from the palette hyprskin built from it (the
  // theme's accent until there is one); it follows each new wallpaper.
  readonly property color accent: (status.palette && status.palette.accent) || Commons.Color.accent
  property color foreground: Commons.Color.imagePicker.text
  property color selectedBorder: Commons.Color.imagePicker.selectedBorder
  property color unselectedBorder: Commons.Color.imagePicker.unselectedBorder
  property int expandedWidth: 768
  property int expandedHeight: 475
  property int sliceWidth: 108
  property int sliceHeight: 432
  property int sliceSpacing: -30
  property int skewOffset: 28
  readonly property int topChromeHeight: Style.space(64)
  readonly property int bottomChromeHeight: 116
  readonly property int previewRadius: Math.max(1, Math.min(16, Math.ceil((panel.width - expandedWidth) / (2 * (sliceWidth + sliceSpacing))) + 1))
  onPreviewRadiusChanged: updateVisibleItems()

  function tabIds() {
    return tabs.map(function(t) { return t.id })
  }

  function expandHome(path) {
    return path.indexOf("~/") === 0 ? home + path.substring(1) : path
  }

  function cleanError(text, fallback) {
    return String(text || "").trim().split("\n").pop().replace(/^hyprskin:\s*/, "") || fallback
  }

  function notify(title, body) {
    Util.execArgv(["notify-send", "-a", "OmaCraft", "-i", "preferences-desktop-wallpaper", title, body || ""])
  }

  // ---------------------------------------------------------------- opening

  // Lifecycle hooks called by omarchy-shell's summon and hide. A payload's
  // "tab" opens that tab: theme, wallhaven, library or favorites.
  function open(payload) {
    var args = {}
    try { args = JSON.parse(payload || "{}") || {} } catch (e) { args = {} }
    if (args.toggle === true && opened) { dismiss(); return }
    error = ""
    filterText = ""
    if (args.tab && tabIds().indexOf(String(args.tab)) >= 0) tab = String(args.tab)
    opened = true
    refreshAll()
    restoreSelection()
    updateVisibleItems()
  }

  function close() {
    opened = false
    filterText = ""
  }

  // Closing from inside goes through the shell, so its open-state
  // bookkeeping stays in step.
  function dismiss() {
    close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function refreshAll() {
    if (!statusProc.running) statusProc.running = true
    if (!themeProc.running) themeProc.running = true
    if (!libraryProc.running) libraryProc.running = true
    if (!favoritesProc.running) favoritesProc.running = true
    if (tab === "wallhaven" && !searchStarted) startSearch()
  }

  function switchTab(index) {
    var count = tabs.length
    var next = tabs[(index + count) % count].id
    if (next === tab) return
    var kept = Object.assign({}, selectedByTab)
    kept[tab] = selectedIndex
    selectedByTab = kept
    filterText = ""
    error = ""
    visibleEntries.clear()
    tab = next
    if (tab === "wallhaven" && !searchStarted) startSearch()
    restoreSelection()
    updateVisibleItems()
  }

  function restoreSelection() {
    var list = entries
    var index = selectedByTab[tab]
    if (index === undefined || index >= list.length) index = Model.indexOfCurrent(list, current)
    selectedIndex = Math.max(0, Math.min(index, list.length - 1))
  }

  // A list arriving again keeps the place in it, by wallpaper rather than
  // by position, unless nothing was chosen yet.
  function replaceList(which, list) {
    var old = which === "theme" ? themeList : which === "wallhaven" ? searchList : which === "library" ? libraryList : favoriteList
    if (JSON.stringify(old) === JSON.stringify(list)) return
    var keepKey = which === tab && entries[selectedIndex] ? entries[selectedIndex].key : ""
    if (which === "theme") themeList = list
    else if (which === "wallhaven") searchList = list
    else if (which === "library") libraryList = list
    else favoriteList = list
    if (which !== tab) return
    var index = -1
    for (var i = 0; keepKey && i < list.length; i++)
      if (list[i].key === keepKey) { index = i; break }
    selectedIndex = index >= 0 ? index : Math.min(selectedIndex, Math.max(0, list.length - 1))
    if (selectedIndex === 0 && !keepKey) selectedIndex = Model.indexOfCurrent(list, current)
    visibleEntries.clear()
    updateVisibleItems()
  }

  // --------------------------------------------------------------- browsing

  readonly property var matchingIndices: Model.matchingIndices(entries, tab === "wallhaven" ? "" : filterText)
  onMatchingIndicesChanged: {
    if (matchingIndices.length > 0 && matchingIndices.indexOf(selectedIndex) < 0) selectedIndex = matchingIndices[0]
    updateVisibleItems()
  }
  onSelectedIndexChanged: {
    updateVisibleItems()
    selectionSettled = false
    settleTimer.restart()
    if (tab === "wallhaven" && selectedIndex >= searchList.length - 8) loadMoreSoon()
  }

  ListModel { id: visibleEntries }

  function updateVisibleItems() {
    Model.syncWindow(visibleEntries, Model.visibleWindow(matchingIndices, selectedIndex, previewRadius))
  }

  function currentEntry() {
    if (matchingIndices.indexOf(selectedIndex) < 0) return null
    return entries[selectedIndex] || null
  }

  function select(index) {
    if (index >= 0 && index < entries.length && matchingIndices.indexOf(index) >= 0) selectedIndex = index
  }

  function selectAdjacent(direction) {
    var position = matchingIndices.indexOf(selectedIndex)
    if (matchingIndices.length === 0) return
    var next = position + direction
    // The search grows as it's browsed, so it doesn't wrap back round.
    if (tab === "wallhaven") next = Math.max(0, Math.min(next, matchingIndices.length - 1))
    else next = (next + matchingIndices.length) % matchingIndices.length
    selectedIndex = matchingIndices[next]
  }

  function setTyped(text) {
    if (tab === "wallhaven") {
      query = text
      searchDebounce.restart()
    } else {
      filterText = text
    }
  }

  Timer {
    id: settleTimer
    interval: 500
    onTriggered: root.selectionSettled = true
  }

  // ---------------------------------------------------------------- Wallhaven

  // The first search is OmaCraft's last one, as hyprskin saved it; only a
  // query typed here replaces it (hyprskin saves every search it runs).
  property bool useSavedSearch: false

  function startSearch() {
    if (searchProc.running) { searchProc.pending = true; return }
    useSavedSearch = !searchStarted
    if (useSavedSearch && status.settings) query = String(savedSearch.query || "")
    searchStarted = true
    searchedQuery = query
    seed = ""
    runSearch(1)
  }

  function runSearch(page) {
    error = ""
    var args = ["python3", hyprskin, "search", "--json", "--page", String(page)]
    if (!useSavedSearch) args.push("--query", searchedQuery)
    if (page > 1 && seed) args.push("--seed", seed)
    searchProc.requestedPage = page
    searchProc.command = args
    searchProc.running = true
  }

  function loadMoreSoon() {
    if (moreResults && !searchProc.running && !pageGap.running) pageGap.start()
  }

  // Wallhaven allows 45 requests a minute; a page every 1.5 s stays under.
  Timer {
    id: pageGap
    interval: 1500
    onTriggered: if (root.moreResults && !searchProc.running) root.runSearch(root.searchPage + 1)
  }

  Timer {
    id: searchDebounce
    interval: 700
    onTriggered: if (root.tab === "wallhaven" && root.query !== root.searchedQuery) root.startSearch()
  }

  // ---------------------------------------------------------------- actions

  // keepColors: set the wallpaper only, leaving the theme as it is.
  function applySelected(keepColors) {
    var entry = currentEntry()
    if (!entry) return
    var args = [hyprskin, entry.target]
    if (keepColors) args.push("--no-theme")
    dismiss()
    applyProc.target = entry.label
    applyProc.command = ["bash", "-c", applyProc.script, "wallpicker"].concat(args)
    applyProc.running = true
  }

  function toggleFavorite() {
    var entry = currentEntry()
    if (!entry) return
    var on = favoriteKeys[entry.key] !== true
    // Flip it straight away, so the heart answers under the cursor.
    if (on) favoritesRaw = [{ key: entry.key, target: entry.target, thumb: entry.preview, local: !entry.meta }].concat(favoritesRaw)
    else favoritesRaw = favoritesRaw.filter(function(f) { return f.key !== entry.key })
    var meta = entry.meta ? { full: entry.meta.full || "", thumbRemote: entry.meta.thumbRemote || "", url: entry.meta.url || "",
                              resolution: entry.meta.resolution || "", colors: entry.meta.colors || [] } : {}
    favoriteQueue = favoriteQueue.concat([["favorite", on ? "add" : "remove", entry.target, "--meta", JSON.stringify(meta)]])
    pumpFavorites()
  }

  property var favoriteQueue: []
  function pumpFavorites() {
    if (favoriteProc.running || favoriteQueue.length === 0) return
    favoriteProc.command = ["python3", hyprskin].concat(favoriteQueue[0])
    favoriteQueue = favoriteQueue.slice(1)
    favoriteProc.running = true
  }

  function emptyText() {
    if (error) return error
    if (tab === "wallhaven") {
      if (searchProc.running && searchList.length === 0) return "Searching Wallhaven…"
      if (searchStarted && searchList.length === 0) return searchedQuery ? "Nothing on Wallhaven for “" + searchedQuery + "”" : "Type to search Wallhaven"
    }
    if (entries.length > 0 && matchingIndices.length === 0) return Commons.I18n.t("common.noMatches")
    if (tab === "theme") return themeProc.running ? "Reading the theme's backgrounds…" : "This theme has no backgrounds"
    if (tab === "library") return libraryProc.running ? "Reading the library…" : "The library is empty. Set a Wallhaven wallpaper to add it."
    if (tab === "favorites") return favoritesProc.running ? "Reading favourites…" : "No favourites yet. Ctrl F hearts the wallpaper in front."
    return ""
  }

  function detailText() {
    var entry = currentEntry()
    if (!entry) return ""
    var bits = []
    if (entry.detail) bits.push(entry.detail)
    if (tab === "wallhaven" && searchTotal > 0) bits.push((matchingIndices.indexOf(selectedIndex) + 1) + " of " + searchTotal)
    else if (matchingIndices.length > 1) bits.push((matchingIndices.indexOf(selectedIndex) + 1) + " of " + matchingIndices.length)
    if (current && (entry.target === current || Model.basename(entry.target) === Model.basename(current))) bits.push("current")
    return bits.join("  ·  ")
  }

  // --------------------------------------------------------------- processes

  Process {
    id: statusProc
    command: ["python3", root.hyprskin, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.status = JSON.parse(text) || {} } catch (e) { return }
        // The saved search arrived after the first one started.
        if (root.useSavedSearch && root.query === "" && root.searchedQuery === "")
          root.query = root.searchedQuery = String(root.savedSearch.query || "")
        // The library's folder comes from the settings; read its thumbnails now.
        if (!thumbsProc.running) thumbsProc.running = true
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.error = "OmaCraft's wallpapers need the Studio plugin. Install it from OmaCraft's Plugins page."
    }
  }

  // The theme's backgrounds, as Omarchy's own switcher lists them, with the
  // thumbnails it keeps.
  Process {
    id: themeProc
    command: ["bash", "-c",
      'name=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null); '
      + 'exec "$1" --print-rows --lazy-thumbnails "$HOME/.local/state/omarchy/current/theme/backgrounds" "$HOME/.config/omarchy/backgrounds/$name"',
      "wallpicker", root.omarchyPath + "/bin/omarchy-menu-images"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.replaceList("theme", Model.themeEntries(text))
    }
  }

  // Omarchy's thumbnails for the library folder, so its cards draw a small
  // picture instead of decoding every full-size download.
  Process {
    id: thumbsProc
    command: [root.omarchyPath + "/bin/omarchy-menu-images", "--print-rows", "--lazy-thumbnails", root.libraryDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.thumbs = Model.parseRows(text).thumbs
        root.replaceList("library", Model.libraryEntries(root.libraryFiles, root.thumbs))
        root.replaceList("favorites", Model.favoriteEntries(root.favoritesRaw, root.thumbs))
      }
    }
  }

  Process {
    id: libraryProc
    command: ["python3", root.hyprskin, "library", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.libraryFiles = JSON.parse(text) || [] } catch (e) { root.libraryFiles = [] }
        root.replaceList("library", Model.libraryEntries(root.libraryFiles, root.thumbs))
      }
    }
  }

  Process {
    id: favoritesProc
    command: ["python3", root.hyprskin, "favorites", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // A heart clicked while this ran is still queued; keep what's shown.
        if (favoriteProc.running || root.favoriteQueue.length) return
        try { root.favoritesRaw = JSON.parse(text) || [] } catch (e) { return }
        root.replaceList("favorites", Model.favoriteEntries(root.favoritesRaw, root.thumbs))
      }
    }
  }

  Process {
    id: favoriteProc
    stderr: StdioCollector { id: favoriteErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.error = root.cleanError(favoriteErr.text, "Couldn't update favourites")
      if (root.favoriteQueue.length) root.pumpFavorites()
      else if (!favoritesProc.running) favoritesProc.running = true
    }
  }

  Process {
    id: searchProc
    property int requestedPage: 1
    property bool pending: false
    stdout: StdioCollector { id: searchOut; waitForEnd: true }
    stderr: StdioCollector { id: searchErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (pending) {
        pending = false
        root.startSearch()
        return
      }
      if (exitCode !== 0) {
        root.error = root.cleanError(searchErr.text, "The Wallhaven search failed")
        return
      }
      try {
        var data = JSON.parse(searchOut.text)
        var incoming = Model.searchEntries(data.results || [])
        var list = requestedPage === 1 ? [] : root.searchList.slice()
        // Toplists shift between pages; drop anything already shown.
        var seen = {}
        for (var i = 0; i < list.length; i++) seen[list[i].key] = true
        for (var j = 0; j < incoming.length; j++)
          if (!seen[incoming[j].key]) { seen[incoming[j].key] = true; list.push(incoming[j]) }
        root.seed = data.seed || root.seed
        root.searchPage = data.page || requestedPage
        root.searchLastPage = data.lastPage || 1
        root.searchTotal = data.total || list.length
        if (requestedPage === 1) root.selectedByTab = Object.assign({}, root.selectedByTab, { wallhaven: 0 })
        root.replaceList("wallhaven", list)
        if (requestedPage === 1 && root.tab === "wallhaven") root.selectedIndex = 0
      } catch (e) {
        root.error = "Unexpected answer from the Wallhaven search"
      }
    }
  }

  // Runs on after the picker has closed: hyprskin downloads a Wallhaven
  // pick into the library, sets it, and rebuilds the theme from it when
  // wallpaper colours are on (omarchy-theme-set, whose hook brings OmaCraft's
  // own parts along). Without that hook, OmaCraft is asked directly.
  Process {
    id: applyProc
    property string target: ""
    readonly property string script: 'hs=$1; shift; '
      + 'if ! err=$(python3 "$hs" apply "$@" 2>&1 >/dev/null); then '
      + '  notify-send -a OmaCraft -i preferences-desktop-wallpaper "Couldn\'t set the wallpaper" "${err##*hyprskin: }"; exit 1; fi; '
      + 'hook="$HOME/.config/omarchy/hooks/theme-set.d/70-omacraft-colors"; '
      + '[[ -e $hook ]] || ! command -v omacraft >/dev/null || omacraft --sync-colors >/dev/null 2>&1; '
      + 'exit 0'
    onExited: {
      if (!statusProc.running) statusProc.running = true
      if (!libraryProc.running) libraryProc.running = true
    }
  }

  // ---------------------------------------------------------------- surface

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omacraft-wallpicker"

    onShownChanged: if (shown) carousel.forceActiveFocus()

    MouseArea {
      anchors.fill: parent
      enabled: root.opened
      onClicked: root.dismiss()
    }

    Item {
      id: card
      width: Math.min(parent.width - 80, root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
      height: root.topChromeHeight + root.expandedHeight + root.bottomChromeHeight
      anchors.centerIn: parent

      MouseArea { anchors.fill: parent; onClicked: {} }

      // ------------------------------------------------------------ tabs

      Row {
        id: tabRow
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(10)

        Repeater {
          model: root.tabs

          // A dark tinted tab, slanted like the slices, so its words read over
          // any wallpaper; the words take the wallpaper's accent.
          delegate: Item {
            id: tabItem
            required property var modelData
            required property int index
            readonly property bool active: root.tab === modelData.id
            readonly property int count: modelData.id === "wallhaven" ? root.searchTotal
              : modelData.id === "library" ? root.libraryList.length
              : modelData.id === "favorites" ? root.favoriteList.length
              : root.themeList.length
            readonly property real skew: 10

            width: tabLabel.implicitWidth + Style.space(36)
            height: Style.space(36)

            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: Qt.rgba(0, 0, 0, tabItem.active ? 0.72 : (tabMouse.containsMouse ? 0.62 : 0.52))
                strokeColor: tabItem.active ? root.accent : Util.alpha(root.accent, 0.25)
                strokeWidth: tabItem.active ? 2 : 1
                startX: tabItem.skew; startY: 0
                PathLine { x: tabItem.width; y: 0 }
                PathLine { x: tabItem.width - tabItem.skew; y: tabItem.height }
                PathLine { x: 0; y: tabItem.height }
                PathLine { x: tabItem.skew; y: 0 }
              }
            }

            Text {
              id: tabLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: tabItem.modelData.label + (tabItem.count > 0 ? "  " + tabItem.count : "")
              color: root.accent
              opacity: tabItem.active ? 1 : (tabMouse.containsMouse ? 0.9 : 0.7)
              font.pixelSize: Style.font.title
              font.weight: tabItem.active ? Font.DemiBold : Font.Normal
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.switchTab(tabItem.index)
            }
          }
        }
      }

      // -------------------------------------------------------- carousel

      Item {
        id: carousel
        anchors.top: parent.top
        anchors.topMargin: root.topChromeHeight
        height: root.expandedHeight
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
        focus: true

        readonly property real itemStep: root.sliceWidth + root.sliceSpacing
        readonly property real previewX: (width - root.expandedWidth) / 2
        readonly property bool mirrored: LayoutMirroring.enabled

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
          var shift = (event.modifiers & Qt.ShiftModifier) !== 0
          if (event.key === Qt.Key_Escape) {
            if (root.typed) root.setTyped("")
            else root.dismiss()
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.tab === "wallhaven" && root.query !== root.searchedQuery) root.startSearch()
            else root.applySelected(shift)
          } else if (ctrl && event.key === Qt.Key_F) {
            root.toggleFavorite()
          } else if (ctrl && event.key === Qt.Key_R) {
            if (root.tab === "wallhaven") root.startSearch()
            else root.refreshAll()
          } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
            root.switchTab(event.key - Qt.Key_1)
          } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && shift)))) {
            root.switchTab(root.tabIndex - 1)
          } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_Tab)) {
            root.switchTab(root.tabIndex + 1)
          } else if (Util.editsFilter(event, root.typed)) {
            root.setTyped(Util.editedFilter(event, root.typed))
          } else if (Util.readingKey(event) === Qt.Key_Left || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && shift)) {
            root.selectAdjacent(-1)
          } else if (Util.readingKey(event) === Qt.Key_Right || event.key === Qt.Key_Tab) {
            root.selectAdjacent(1)
          } else if (event.key === Qt.Key_Home) {
            if (root.matchingIndices.length) root.select(root.matchingIndices[0])
          } else if (event.key === Qt.Key_End) {
            if (root.matchingIndices.length) root.select(root.matchingIndices[root.matchingIndices.length - 1])
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
                     && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            root.setTyped(root.typed + event.text)
          } else {
            return
          }
          event.accepted = true
        }

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          property real pending: 0
          onWheel: function(event) {
            pending += event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x
            while (Math.abs(pending) >= 120) {
              root.selectAdjacent(pending > 0 ? -1 : 1)
              pending -= pending > 0 ? 120 : -120
            }
          }
        }

        Text {
          visible: root.matchingIndices.length === 0 || (root.error && root.entries.length === 0)
          anchors.centerIn: parent
          width: root.expandedWidth
          textFormat: Text.PlainText
          text: root.emptyText()
          color: root.foreground
          style: Text.Outline
          styleColor: Util.alpha(root.dimColor, 0.7)
          font.pixelSize: Style.font.title
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: visibleEntries

          delegate: Item {
            id: item
            required property int entryIndex
            required property int relativeIndex

            readonly property var entry: root.entries[entryIndex]
            readonly property string preview: entry ? String(entry.preview || "") : ""
            readonly property string full: entry ? String(entry.full || "") : ""
            readonly property bool selected: entryIndex === root.selectedIndex
            readonly property bool favorite: entry ? root.favoriteKeys[entry.key] === true : false

            readonly property real readingX: selected ? carousel.previewX : (relativeIndex < 0 ? carousel.previewX + relativeIndex * carousel.itemStep : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relativeIndex - 1) * carousel.itemStep)
            x: carousel.mirrored ? carousel.width - readingX - width : readingX
            width: selected ? root.expandedWidth : root.sliceWidth
            height: selected ? root.expandedHeight : root.sliceHeight
            y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
            z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)

            readonly property real skAbs: Math.abs(root.skewOffset)
            readonly property real topLeft: root.skewOffset >= 0 ? skAbs : 0
            readonly property real topRight: root.skewOffset >= 0 ? width : width - skAbs
            readonly property real bottomRight: root.skewOffset >= 0 ? width - skAbs : width
            readonly property real bottomLeft: root.skewOffset >= 0 ? 0 : skAbs

            function sourceFor(path) {
              if (!path || !root.opened) return ""
              return path.indexOf("://") >= 0 ? path : Util.fileUrl(path)
            }

            Item {
              id: maskShape
              anchors.fill: parent
              visible: false
              layer.enabled: true

              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "white"
                  strokeColor: "transparent"
                  startX: item.topLeft; startY: 0
                  PathLine { x: item.topRight; y: 0 }
                  PathLine { x: item.bottomRight; y: item.height }
                  PathLine { x: item.bottomLeft; y: item.height }
                  PathLine { x: item.topLeft; y: 0 }
                }
              }
            }

            Item {
              anchors.fill: parent
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskShape
                maskThresholdMin: 0.3
                maskSpreadAtMin: 0.3
              }

              Rectangle { anchors.fill: parent; color: root.dimColor }

              Image {
                id: image
                anchors.fill: parent
                source: item.sourceFor(item.preview)
                sourceSize.width: Math.ceil(root.expandedWidth * Screen.devicePixelRatio)
                sourceSize.height: Math.ceil(root.expandedHeight * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
              }

              // Wallhaven's previews are small; the one in front fetches the
              // wallpaper itself once the selection rests on it.
              Image {
                anchors.fill: parent
                source: item.selected && root.selectionSettled ? item.sourceFor(item.full) : ""
                sourceSize.width: Math.ceil(root.expandedWidth * Screen.devicePixelRatio)
                sourceSize.height: Math.ceil(root.expandedHeight * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
              }

              Rectangle {
                anchors.fill: parent
                color: Util.alpha(root.dimColor, item.selected ? 0 : 0.42)
              }
            }

            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: "transparent"
                strokeColor: item.selected ? root.selectedBorder : root.unselectedBorder
                strokeWidth: item.selected ? 3 : 1
                startX: item.topLeft; startY: 0
                PathLine { x: item.topRight; y: 0 }
                PathLine { x: item.bottomRight; y: item.height }
                PathLine { x: item.bottomLeft; y: item.height }
                PathLine { x: item.topLeft; y: 0 }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (item.selected) root.applySelected((mouse.modifiers & Qt.ShiftModifier) !== 0)
                else root.select(item.entryIndex)
              }
            }

            // The heart: on the card in front, and on any favourite.
            Text {
              visible: item.selected || item.favorite
              anchors.top: parent.top
              anchors.topMargin: item.selected ? 14 : 10
              anchors.right: parent.right
              anchors.rightMargin: item.selected ? 22 : 14
              textFormat: Text.PlainText
              text: item.favorite ? "♥" : "♡"
              color: item.favorite ? root.selectedBorder : root.foreground
              opacity: item.selected ? (heartMouse.containsMouse ? 1 : 0.9) : 0.75
              style: Text.Outline
              styleColor: Util.alpha(root.dimColor, 0.8)
              font.pixelSize: item.selected ? Style.font.display : Style.font.body

              MouseArea {
                id: heartMouse
                anchors.fill: parent
                anchors.margins: -8
                enabled: item.selected
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleFavorite()
              }
            }
          }
        }
      }

      // ------------------------------------------------------- labels

      Text {
        id: selectedLabel
        anchors.top: carousel.bottom
        anchors.topMargin: Style.space(14)
        anchors.horizontalCenter: carousel.horizontalCenter
        width: root.expandedWidth
        textFormat: Text.PlainText
        text: root.currentEntry() ? root.currentEntry().label : ""
        color: root.foreground
        style: Text.Outline
        styleColor: Util.alpha(root.dimColor, 0.7)
        font.pixelSize: Style.font.display
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      Text {
        id: detailLabel
        anchors.top: selectedLabel.bottom
        anchors.topMargin: Style.space(4)
        anchors.horizontalCenter: carousel.horizontalCenter
        width: root.expandedWidth
        textFormat: Text.PlainText
        text: root.typed
          ? (root.tab === "wallhaven" ? "Search: " : "Filter: ") + root.typed + (searchProc.running ? "  ·  searching…" : "")
          : root.detailText() + (root.tab === "wallhaven" && searchProc.running ? "  ·  loading…" : "")
        color: root.foreground
        opacity: 0.85
        style: Text.Outline
        styleColor: Util.alpha(root.dimColor, 0.7)
        font.pixelSize: Style.font.title
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      Text {
        anchors.top: detailLabel.bottom
        anchors.topMargin: Style.space(10)
        anchors.horizontalCenter: carousel.horizontalCenter
        width: root.expandedWidth
        textFormat: Text.PlainText
        text: (root.tab === "wallhaven" ? "type to search" : "type to filter")
          + "  ·  ↑ ↓ tabs  ·  Enter set  ·  Shift Enter keep the colours  ·  Ctrl F favourite  ·  Esc close"
        color: root.foreground
        opacity: 0.55
        style: Text.Outline
        styleColor: Util.alpha(root.dimColor, 0.7)
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }

  // omarchy-shell wallpicker open|toggle [tab], for keys and scripts.
  IpcHandler {
    target: "wallpicker"

    function open(tab: string): void { root.open(JSON.stringify({ tab: tab })) }
    function toggle(tab: string): void { root.open(JSON.stringify({ tab: tab, toggle: true })) }
    function close(): void { root.dismiss() }
  }
}

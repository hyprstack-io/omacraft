import QtQuick
import Quickshell
import Quickshell.Io

// Everything the wallpaper pages share: Hyprskin status and settings, the
// Wallhaven search, local folders and the downloaded library. All work happens
// in bin/hyprskin; Background.qml (this plugin's service) renders transitions
// and runs the auto-change timer.
Item {
  id: store

  // Set by the hub: whether it is showing, and which page is in front, so
  // background paging only runs while someone is looking.
  property bool active: false
  property string page: ""

  readonly property string script: decodeURIComponent(Qt.resolvedUrl("../bin/hyprskin").toString().replace(/^file:\/\//, ""))

  signal searchRestarted()
  signal localRestarted()

  property var status: ({})
  readonly property var cfg: status.settings || {}
  readonly property var searchSettings: cfg.search || {}
  readonly property var transition: cfg.transition || {}
  readonly property var paletteSettings: cfg.palette || {}
  readonly property var rotationCfg: cfg.rotation || {}
  readonly property var colors: status.palette || {}
  readonly property var localCfg: cfg.local || {}
  readonly property var localFolders: localCfg.folders || []

  // Which interface parts follow the wallpaper (bin/hyprskin targets --json).
  property var targetInfo: ({})
  readonly property var targets: targetInfo.targets || []
  readonly property var themeSlugs: targetInfo.themes || []
  readonly property var accentRoles: targetInfo.accentRoles || []

  property string busyTarget: ""
  property string error: ""
  property real now: Date.now()
  readonly property bool applying: applyProc.running

  readonly property var swatchKeys: [
    "background", "lighter_background", "foreground", "accent",
    "red", "orange", "yellow", "green", "cyan", "blue", "magenta"
  ]

  function basename(path) {
    var s = String(path || "")
    return s.substring(s.lastIndexOf("/") + 1)
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
    if (!targetsProc.running) targetsProc.running = true
  }

  // ------------------------------------------------------------ Wallhaven

  // Search form, seeded from the saved search the first time status arrives.
  property bool formSeeded: false
  property string query: ""
  property string sorting: "toplist"
  property string topRange: "1M"
  property string categories: "111"
  property string purity: "100"
  property string atleast: ""
  property string ratios: ""

  property var results: []
  property var resultIds: ({})
  property string seed: ""
  // A new search asked for while a page was still loading; runs when it lands.
  property bool searchPending: false
  property int pageNumber: 1
  property int lastPage: 1
  property int total: 0
  property bool searched: false
  readonly property bool searching: searchProc.running

  // Pages keep loading in the background; this caps one search's memory and disk use.
  readonly property int maxPages: 40
  readonly property bool moreAvailable: searched && results.length > 0
    && pageNumber < lastPage && pageNumber < maxPages

  function seedForm() {
    if (formSeeded || !status.settings) return
    formSeeded = true
    query = searchSettings.query || ""
    sorting = searchSettings.sorting || "toplist"
    topRange = searchSettings.topRange || "1M"
    categories = searchSettings.categories || "111"
    purity = searchSettings.purity || "100"
    atleast = searchSettings.atleast || ""
    ratios = searchSettings.ratios || ""
    localSort = localCfg.sort || "newest"
  }

  // Page 1 starts a new search; later pages are appended as the grid scrolls.
  function search(requested) {
    requested = Math.max(1, requested || 1)
    if (searchProc.running) {
      if (requested === 1) searchPending = true
      return
    }
    error = ""
    if (requested === 1) {
      seed = ""
      results = []
      resultIds = ({})
      lastPage = 1
      total = 0
      store.searchRestarted()
    }
    searchProc.requestedPage = requested
    searchProc.command = ["python3", script, "search", "--json",
      "--query", query,
      "--sorting", sorting,
      "--top-range", topRange,
      "--categories", categories,
      "--purity", purity,
      "--atleast", atleast,
      "--ratios", ratios,
      "--seed", seed,
      "--page", String(requested)]
    searchProc.running = true
  }

  function loadMore() {
    if (searchProc.running || !moreAvailable) return
    search(pageNumber + 1)
  }

  function toggleBit(mask, index) {
    var bits = String(mask || "000").split("")
    bits[index] = bits[index] === "1" ? "0" : "1"
    var out = bits.join("")
    return out === "000" ? mask : out
  }

  // ---------------------------------------------------------------- Local

  property var localResults: []
  property int localPage: 1
  property int localLastPage: 1
  property int localTotal: 0
  property string localSeed: ""
  property bool localSearched: false
  property bool localPending: false
  property bool localRefresh: false
  property string localQuery: ""
  property string localSort: "newest"
  readonly property bool scanning: localProc.running
  readonly property bool localMore: localSearched && localResults.length > 0 && localPage < localLastPage

  function localSearch(requested, rescan) {
    requested = Math.max(1, requested || 1)
    if (rescan) localRefresh = true
    if (localProc.running) {
      if (requested === 1) localPending = true
      return
    }
    error = ""
    if (requested === 1) {
      localSeed = ""
      localResults = []
      localLastPage = 1
      localTotal = 0
      store.localRestarted()
    }
    var args = ["python3", script, "local", "--json",
      "--query", localQuery.trim(),
      "--sort", localSort,
      "--min-width", String(Number(localCfg.minWidth) || 0),
      "--seed", localSeed,
      "--page", String(requested)]
    if (localRefresh && requested === 1) args.push("--refresh")
    localRefresh = false
    localProc.requestedPage = requested
    localProc.command = args
    localProc.running = true
  }

  function localLoadMore() {
    if (localProc.running || !localMore) return
    localSearch(localPage + 1)
  }

  function folderAction(action, path) {
    if (folderProc.running) return
    folderProc.command = ["python3", script, "folder", action, path]
    folderProc.running = true
  }

  function pickFolder() {
    if (!pickerProc.running) pickerProc.running = true
  }

  // -------------------------------------------------------------- Library

  property var library: []

  function refreshLibrary() {
    if (!libraryProc.running) libraryProc.running = true
  }

  function deleteFromLibrary(path) {
    // Drop the tile straight away; the rescan after the delete confirms it.
    library = library.filter(function(e) { return e.path !== path })
    deleteQueue = deleteQueue.concat([path])
    pumpDelete()
  }

  property var deleteQueue: []
  function pumpDelete() {
    if (deleteProc.running || deleteQueue.length === 0) return
    deleteProc.command = ["python3", script, "delete", deleteQueue[0]]
    deleteQueue = deleteQueue.slice(1)
    deleteProc.running = true
  }

  // ------------------------------------------------------------ Favorites
  //
  // Studio's own list (Wallhaven's API cannot write to your collections).
  // Wallhaven wallpapers are keyed by id, so a search result, its library
  // file and a collection entry share one heart; other files by path.

  property var favorites: []
  readonly property var favoriteKeys: {
    var keys = {}
    for (var i = 0; i < favorites.length; i++) keys[favorites[i].key] = true
    return keys
  }

  function favoriteKey(idOrPath) {
    var s = String(idOrPath || "")
    var name = basename(s)
    var m = name.match(/^wallhaven-([a-z0-9]+)\.\w+$/)
    if (m) return m[1]
    return s
  }

  function isFavorite(idOrPath) {
    return favoriteKeys[favoriteKey(idOrPath)] === true
  }

  // target: a Wallhaven id or a local path; meta: a search result, for its preview.
  function toggleFavorite(target, meta) {
    var key = favoriteKey(target)
    var on = !isFavorite(target)
    // Optimistic, so the heart flips under the cursor.
    if (on) favorites = [{ key: key, target: target, thumb: (meta && meta.thumb) || target, local: !meta }].concat(favorites)
    else favorites = favorites.filter(function(f) { return f.key !== key })
    var m = meta ? { full: meta.full || "", thumbRemote: meta.thumbRemote || "", url: meta.url || "",
                     resolution: meta.resolution || "", colors: meta.colors || [] } : {}
    favQueue = favQueue.concat([["favorite", on ? "add" : "remove", target, "--meta", JSON.stringify(m)]])
    pumpFavorite()
  }

  property var favQueue: []
  function pumpFavorite() {
    if (favoriteProc.running || favQueue.length === 0) return
    favoriteProc.command = ["python3", script].concat(favQueue[0])
    favQueue = favQueue.slice(1)
    favoriteProc.running = true
  }

  function refreshFavorites() {
    if (!favoritesProc.running) favoritesProc.running = true
  }

  // -------------------------------------------------------------- Account

  property var account: ({})
  property string accountError: ""
  readonly property bool accountLoading: accountProc.running
  readonly property var collections: account.collections || []

  function refreshAccount() {
    accountError = ""
    if (!cfg.apiKey) { account = ({}); return }
    if (!accountProc.running) accountProc.running = true
  }

  property int collectionId: 0
  property var collectionResults: []
  property int collectionPage: 1
  property int collectionLastPage: 1
  property int collectionTotal: 0
  property bool collectionPending: false
  readonly property bool collectionLoading: collectionProc.running
  readonly property bool collectionMore: collectionResults.length > 0 && collectionPage < collectionLastPage

  function openCollection(id) {
    if (collectionProc.running) { if (id !== collectionId) { collectionId = id; collectionPending = true }; return }
    collectionId = id
    collectionResults = []
    collectionPage = 1
    collectionLastPage = 1
    collectionTotal = 0
    loadCollection(1)
  }

  function loadCollection(n) {
    if (collectionProc.running || !collectionId) return
    accountError = ""
    collectionProc.requestedPage = n
    collectionProc.command = ["python3", script, "collection", String(collectionId), "--page", String(n), "--json"]
    collectionProc.running = true
  }

  function collectionLoadMore() {
    if (collectionMore) loadCollection(collectionPage + 1)
  }

  function useAccountFilters() {
    if (filtersProc.running) return
    filtersProc.running = true
  }

  function openUrl(url) {
    if (url) Quickshell.execDetached(["xdg-open", url])
  }

  // -------------------------------------------------------------- Actions

  function apply(target, extra) {
    if (applyProc.running) return
    error = ""
    busyTarget = target
    applyProc.command = ["python3", script, "apply", target].concat(extra || [])
    applyProc.running = true
  }

  function runAction(args) {
    if (applyProc.running) return
    error = ""
    busyTarget = args[0]
    applyProc.command = ["python3", script].concat(args)
    applyProc.running = true
  }

  function isCurrent(path, name) {
    var cur = status.current || ""
    return cur !== "" && (cur === path || basename(cur) === (name || basename(path)))
  }

  // Settings writes go through a queue so quick clicks do not clobber each other.
  property var setQueue: []
  function setOption(key, value, after) {
    setQueue = setQueue.concat([{ key: key, value: JSON.stringify(value), after: after || "" }])
    pumpSet()
  }

  function pumpSet() {
    if (setProc.running || setQueue.length === 0) return
    var next = setQueue[0]
    setQueue = setQueue.slice(1)
    setProc.after = next.after
    setProc.command = ["python3", script, "set", next.key, next.value]
    setProc.running = true
  }

  // Palette changes re-theme straight away whenever wallpaper colors are in use.
  function setPaletteOption(key, value) {
    var live = cfg.dynamicColors !== false || status.themeIsDynamic
    setOption(key, value, live ? "retheme" : "")
  }

  // Which parts follow the wallpaper; rebuilds the theme while it is in use.
  function setTargetOption(key, value) {
    setOption(key, value, status.themeIsDynamic ? "retheme" : "")
  }

  // ------------------------------------------------------------ Auto-change

  function intervalLabel(minutes) {
    return minutes >= 60 ? (minutes / 60) + "h" : minutes + "m"
  }

  function countdownText() {
    var minutes = Number(rotationCfg.interval) || 0
    if (minutes <= 0) return "Auto-change is off"
    var last = (Number(status.lastChangedAt) || 0) * 1000
    if (!last) return "Every " + intervalLabel(minutes)
    var left = Math.max(0, last + minutes * 60000 - now)
    var h = Math.floor(left / 3600000)
    var m = Math.floor((left % 3600000) / 60000)
    var s = Math.floor((left % 60000) / 1000)
    var clock = h > 0 ? h + "h " + m + "m" : (m > 0 ? m + "m " + s + "s" : s + "s")
    return "Next change in " + clock
  }

  // ------------------------------------------------------------ lifecycle

  Component.onCompleted: refresh()
  onActiveChanged: {
    if (active) {
      error = ""
      refresh()
      refreshLibrary()
      refreshFavorites()
    }
  }
  onPageChanged: {
    if (page === "local" && !localSearched) localSearch(1)
    if (page === "library") refreshLibrary()
    if (page === "favorites" || page === "library") refreshFavorites()
  }

  // Local pages are cheap (no rate limit), so they stream in quickly.
  Timer {
    interval: 250
    repeat: true
    running: store.active && store.page === "local" && store.localMore && !localProc.running
    onTriggered: store.localLoadMore()
  }

  // Eager loading: fetch the next page as soon as one lands, spaced to stay
  // under Wallhaven's 45 requests/minute. Pauses while the hub is closed.
  Timer {
    interval: 1500
    repeat: true
    running: store.active && store.page === "wallhaven" && store.moreAvailable && !searchProc.running
    onTriggered: store.loadMore()
  }

  Timer {
    interval: 1000
    repeat: true
    running: store.active && (Number(store.rotationCfg.interval) || 0) > 0
    onTriggered: store.now = Date.now()
  }

  // Collections load page by page like a search, within the rate limit.
  Timer {
    interval: 1500
    repeat: true
    running: store.active && store.page === "account" && store.collectionMore && !collectionProc.running
    onTriggered: store.collectionLoadMore()
  }

  // ------------------------------------------------------------ processes

  Process {
    id: deleteProc
    stderr: StdioCollector { id: deleteErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) store.error = String(deleteErr.text || "").trim().replace(/^hyprskin:\s*/, "") || "Could not delete"
      if (store.deleteQueue.length) store.pumpDelete()
      else store.refreshLibrary()
    }
  }

  Process {
    id: favoriteProc
    stderr: StdioCollector { id: favoriteErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) store.error = String(favoriteErr.text || "").trim().replace(/^hyprskin:\s*/, "") || "Could not update favorites"
      if (store.favQueue.length) store.pumpFavorite()
      else store.refreshFavorites()
    }
  }

  Process {
    id: favoritesProc
    command: ["python3", store.script, "favorites", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // A heart clicked while this ran is still queued; keep the optimistic list.
        if (favoriteProc.running || store.favQueue.length) return
        try { store.favorites = JSON.parse(text) } catch (e) { }
      }
    }
  }

  Process {
    id: accountProc
    command: ["python3", store.script, "account", "--json"]
    stdout: StdioCollector { id: accountOut; waitForEnd: true }
    stderr: StdioCollector { id: accountErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        store.accountError = String(accountErr.text || "").trim().replace(/^hyprskin:\s*/, "") || "Could not reach Wallhaven"
        return
      }
      try { store.account = JSON.parse(accountOut.text) } catch (e) { store.accountError = "Unexpected account response" }
    }
  }

  Process {
    id: collectionProc
    property int requestedPage: 1
    stdout: StdioCollector { id: collectionOut; waitForEnd: true }
    stderr: StdioCollector { id: collectionErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (store.collectionPending) {
        store.collectionPending = false
        store.openCollection(store.collectionId)
        return
      }
      if (exitCode !== 0) {
        store.accountError = String(collectionErr.text || "").trim().replace(/^hyprskin:\s*/, "") || "Could not open the collection"
        return
      }
      try {
        var data = JSON.parse(collectionOut.text)
        var incoming = data.results || []
        store.collectionResults = requestedPage === 1 ? incoming : store.collectionResults.concat(incoming)
        store.collectionPage = data.page || requestedPage
        store.collectionLastPage = data.lastPage || 1
        store.collectionTotal = data.total || 0
      } catch (e) {
        store.accountError = "Unexpected collection response"
      }
    }
  }

  Process {
    id: filtersProc
    command: ["python3", store.script, "use-account-filters"]
    stderr: StdioCollector { id: filtersErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        store.accountError = String(filtersErr.text || "").trim().replace(/^hyprskin:\s*/, "")
        return
      }
      // Reseed the Wallhaven form from the new saved search.
      store.formSeeded = false
      store.refresh()
    }
  }

  Process {
    id: statusProc
    command: ["python3", store.script, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          store.status = JSON.parse(text)
          store.seedForm()
        } catch (e) {
          store.error = "Could not read Hyprskin status"
        }
      }
    }
  }

  Process {
    id: targetsProc
    command: ["python3", store.script, "targets", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { store.targetInfo = JSON.parse(text) } catch (e) { }
      }
    }
  }

  Process {
    id: localProc
    property int requestedPage: 1
    stdout: StdioCollector { id: localOut; waitForEnd: true }
    stderr: StdioCollector { id: localErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (store.localPending) {
        store.localPending = false
        store.localSearch(1)
        return
      }
      store.localSearched = true
      if (exitCode !== 0) {
        store.error = String(localErr.text || "").trim().replace(/^hyprskin:\s*/, "") || "Could not read local folders"
        return
      }
      try {
        var data = JSON.parse(localOut.text)
        var incoming = data.results || []
        store.localResults = requestedPage === 1 ? incoming : store.localResults.concat(incoming)
        store.localSeed = data.seed || store.localSeed
        store.localPage = data.page || requestedPage
        store.localLastPage = data.lastPage || 1
        store.localTotal = data.total || 0
        if ((data.missing || []).length) store.error = "Folder not found: " + data.missing.join(", ")
      } catch (e) {
        store.error = "Unexpected response from local search"
      }
    }
  }

  Process {
    id: pickerProc
    command: ["omarchy-file-select", "--directory", "--title", "Add a wallpaper folder"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text || "").trim().split("\n")[0]
        if (path) store.folderAction("add", path)
      }
    }
  }

  Process {
    id: folderProc
    stderr: StdioCollector { id: folderErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        store.error = String(folderErr.text || "").trim().replace(/^hyprskin:\s*/, "")
        return
      }
      store.refresh()
      store.localSearch(1, true)
    }
  }

  Process {
    id: libraryProc
    command: ["python3", store.script, "library", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { store.library = JSON.parse(text) } catch (e) { store.library = [] }
      }
    }
  }

  Process {
    id: searchProc
    property int requestedPage: 1
    stdout: StdioCollector { id: searchOut; waitForEnd: true }
    stderr: StdioCollector { id: searchErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (store.searchPending) {
        store.searchPending = false
        store.search(1)
        return
      }
      store.searched = true
      if (exitCode !== 0) {
        store.error = String(searchErr.text || "").trim().replace(/^hyprskin:\s*/, "") || "Search failed"
        return
      }
      try {
        var data = JSON.parse(searchOut.text)
        // Toplists shift while you scroll, so drop anything already shown.
        var seen = requestedPage === 1 ? ({}) : Object.assign({}, store.resultIds)
        var fresh = []
        var incoming = data.results || []
        for (var i = 0; i < incoming.length; i++) {
          if (seen[incoming[i].id]) continue
          seen[incoming[i].id] = true
          fresh.push(incoming[i])
        }
        store.results = requestedPage === 1 ? fresh : store.results.concat(fresh)
        store.resultIds = seen
        store.seed = data.seed || store.seed
        store.pageNumber = data.page || requestedPage
        store.lastPage = data.lastPage || 1
        store.total = data.total || 0
      } catch (e) {
        store.error = "Unexpected search response"
      }
    }
  }

  Process {
    id: applyProc
    stderr: StdioCollector { id: applyErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        store.error = String(applyErr.text || "").trim().replace(/^hyprskin:\s*/, "") || "Could not apply wallpaper"
      store.busyTarget = ""
      store.refresh()
      store.refreshLibrary()
    }
  }

  Process {
    id: setProc
    property string after: ""
    stderr: StdioCollector { id: setErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) store.error = String(setErr.text || "").trim().replace(/^hyprskin:\s*/, "")
      if (after === "retheme" && store.setQueue.length === 0) store.runAction(["theme"])
      store.refresh()
      store.pumpSet()
    }
  }
}

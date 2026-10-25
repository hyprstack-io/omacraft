import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// omascii boot screen designer. The left pane picks the art: a TAAG-style
// "test all" gallery of every figlet.js font (or every TheDraw, or system
// font drawn as pixels) rendering your text, a grid of your images, or your
// library of saved and previously applied boot screens. The right pane
// previews it live in the boot screen colours (and plays the intro in
// place), with the settings below as tabs of option chips. The work lives in
// bin/omascii: this overlay lists, renders (omascii render --json / frames),
// keeps the settings (omascii set), saves to the library (omascii saved) and
// opens a floating terminal for the sudo steps (apply / restore).
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property string cli: pluginDir + "/bin/omascii"

  // Saved settings (from omascii status) and the draft being edited: the
  // same keys as ~/.config/omascii/config.json. The draft is written back on
  // every change, so closing the window never loses work.
  property var status: null
  property var draft: ({})

  // What the left pane shows: "figlet", "tdf" (TheDraw), "ttf" (system
  // fonts as pixels), "image" or "saved" (the library)
  property string fontSet: "figlet"
  readonly property bool fontMode: fontSet === "figlet" || fontSet === "tdf" || fontSet === "ttf"
  readonly property bool draftIsTdf: String(draft.font || "").toLowerCase().indexOf("tdf ") === 0
  readonly property int tdfCount: status && status.tdf ? status.tdf.count : 0
  readonly property int ttfCount: status && status.ttf ? status.ttf.count : 0

  property var gallery: []          // [{font, art, codes?, cols, rows}]
  property string filterText: ""
  property int selectedIndex: 0
  property bool galleryPending: false
  property bool galleryLoaded: false
  // TheDraw and system fonts are filtered by the CLI and arrive in pages.
  // The list holds a row for every match from the start (named, art still
  // to come), and the pages in view render as you scroll or jump.
  readonly property bool paged: fontSet === "tdf" || fontSet === "ttf"
  readonly property int pageSize: fontSet === "ttf" ? 60 : 120
  property int pageTotal: 0
  property var pagesLoaded: ({})     // page offset -> true
  property var pageQueue: []         // page offsets waiting to render
  property int galleryGen: 0         // bumped by each fresh listing
  property int galleryProcGen: 0     // the listing the running page belongs to

  // Font names in list order, for the jump bar's labels and letter marks
  property var fontNames: []

  property var images: []           // [{path, name, dir}]
  property int imageIndex: -1

  // The library: [{id, name, kind, at, config, text, html, cols, rows, foreground, error}]
  property var saved: []
  property bool savedLoaded: false
  property int savedIndex: -1
  property string confirmDelete: ""  // id awaiting a second click
  property bool naming: false        // the "Save to library" name field is showing

  // Live preview of the focused font or image with every setting
  property var previewArt: null     // {text, html, cols, rows, foreground, background}
  property string previewError: ""
  property bool previewPending: false
  property string previewKey: ""

  // Boot intro played in place: frames of rich text at 50 fps
  property var anim: null           // {frames, hold, cols, rows, background, effect}
  property int animFrame: 0
  property bool animPlaying: false
  property bool animLoading: false
  property string animEffect: ""

  property string settingsTab: "text"

  // DOS text palette, for TheDraw colour codes
  readonly property var dosColors: ["#000000", "#0000aa", "#00aa00", "#00aaaa", "#aa0000", "#aa00aa", "#aa5500", "#aaaaaa",
    "#555555", "#5555ff", "#55ff55", "#55ffff", "#ff5555", "#ff55ff", "#ffff55", "#ffffff"]
  property string message: ""
  property bool messageIsError: false

  readonly property var colorNames: ["accent", "foreground", "bright_foreground", "blue", "cyan",
    "green", "magenta", "red", "yellow", "orange", "bright_blue", "bright_cyan", "bright_green",
    "bright_magenta", "bright_red", "bright_yellow"]
  readonly property var fillOptions: [
    { value: "", label: "Font's own" }, { value: "█", label: "█ solid" }, { value: "▓", label: "▓ dark shade" },
    { value: "▒", label: "▒ shade" }, { value: "#", label: "# hash" }, { value: "@", label: "@ at" },
    { value: "*", label: "* star" }, { value: "01", label: "01 binary" }, { value: "·", label: "· dots" },
    { value: "╳", label: "╳ cross" }]
  readonly property var charsetLabels: ({
    ascii: "ASCII ramp", detailed: "Detailed ramp", blocks: "Shade blocks ░▒▓█", braille: "Braille ⣿",
    quadrant: "Quadrants ▚", halfblock: "Half blocks ▀ (colour)", custom: "Custom ramp" })
  readonly property var layoutLabels: ({
    "default": "Font default", "full": "Full width", "fitted": "Fitted",
    "controlled smushing": "Controlled smushing", "universal smushing": "Universal smushing" })

  readonly property var focusedEntry: selectedIndex >= 0 && selectedIndex < displayModel.count
    ? displayModel.get(selectedIndex) : null
  // The draft differs from what is installed on the boot screen
  readonly property bool notOnBoot: !!status && (!status.applied || !sameSettings(draft, status.applied)
    || status.plymouthTheme !== "omascii")
  readonly property bool needsEffect: draft.style === "animated" && (draft.effects || []).length === 0

  // Shares the [menu] surface tokens, like the other Omarchy pickers
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  property string uiFont: Style.font.menuFamily
  property string monoFont: Style.font.family
  readonly property int pad: Style.spacing.panelPadding
  readonly property int gap: Style.spacing.md

  // ---------------------------------------------------------------- lifecycle

  function open(payloadJson) {
    root.opened = true
    root.message = ""
    root.filterText = ""
    root.naming = false
    searchField.text = ""
    refreshStatus()
    refreshSaved()
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function close() {
    flushDraft()
    root.opened = false
    stopAnimation()
  }

  // Hiding unloads this overlay, so anything to run afterwards (a terminal)
  // must be started before calling it
  function dismiss() {
    flushDraft()
    root.opened = false
    stopAnimation()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "omacraft.omascii")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // ---------------------------------------------------------------- draft

  // Same settings, ignoring keys only one side has (applied.json adds "at")
  function sameSettings(a, b) {
    if (!a || !b) return false
    var keys = Object.keys(status && status.config ? status.config : a)
    for (var i = 0; i < keys.length; i++)
      if (JSON.stringify(a[keys[i]]) !== JSON.stringify(b[keys[i]])) return false
    return true
  }

  // Keys whose change re-renders the gallery, per collection
  readonly property var galleryKeys: ({
    figlet: ["text", "hlayout", "vlayout", "width", "whitespaceBreak"],
    tdf: ["text"],
    ttf: ["text", "ttfRows", "ttfCharset", "threshold", "dither"],
    image: [],
    saved: []
  })

  function setDraft(key, value) {
    if (JSON.stringify(draft[key]) === JSON.stringify(value)) return
    var next = Object.assign({}, draft)
    next[key] = value
    draft = next
    if ((galleryKeys[fontSet] || []).indexOf(key) !== -1) requestGallery()
    draftEdited()
  }

  function draftEdited() {
    autosaveTimer.restart()
    requestPreview()
  }

  function loadDraft(config) {
    draft = Object.assign({}, config)
    textField.text = String(config.text).replace(/\n/g, "\\n")
    imagePathField.text = String(config.image || "")
  }

  // Write the draft to config.json. Detached, so it survives the overlay
  // unloading on close.
  function flushDraft() {
    autosaveTimer.stop()
    if (!status || !status.config || sameSettings(draft, status.config) || needsEffect) return
    Quickshell.execDetached([root.cli, "set", "--config-json", JSON.stringify(draft)])
    var s = Object.assign({}, status)
    s.config = Object.assign({}, draft)
    status = s
  }

  // ---------------------------------------------------------------- data

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  function refreshSaved() {
    if (!savedProc.running) savedProc.running = true
  }

  function setFontSet(next) {
    if (fontSet === next) return
    fontSet = next
    gallery = []
    galleryLoaded = false
    displayModel.clear()
    fontNames = []
    confirmDelete = ""
    if (next === "image") {
      if (!imagesProc.running) imagesProc.running = true
      requestPreview()
    } else if (next === "saved") {
      refreshSaved()
      requestPreview()
    } else {
      runGallery()
    }
  }

  function requestGallery() {
    galleryTimer.restart()
  }

  // A fresh listing (offset 0, with every name), or one page of a paged set
  function runGallery(pageOffset) {
    if (!fontMode) return
    var fresh = pageOffset === undefined
    if (galleryProc.running) {
      if (fresh) galleryPending = true
      return
    }
    if (fresh) {
      galleryPending = false
      galleryGen++
      pageQueue = []
    }
    galleryProcGen = galleryGen
    var cmd = [root.cli, "gallery", "--config-json", JSON.stringify(draft),
      "--text", String(draft.text || "omascii"), "--set", fontSet]
    if (paged)
      cmd = cmd.concat(["--limit", String(pageSize), "--offset", String(fresh ? 0 : pageOffset),
                        "--filter", filterText])
    galleryProc.command = cmd
    galleryProc.running = true
  }

  // Queue the pages covering rows first..last that haven't rendered
  function ensureRows(first, last) {
    if (!paged || !galleryLoaded || pageTotal === 0) return
    first = Math.max(0, first)
    last = Math.min(pageTotal - 1, Math.max(first, last))
    var queue = pageQueue.slice()
    for (var p = Math.floor(first / pageSize) * pageSize; p <= last; p += pageSize)
      if (!pagesLoaded[p] && queue.indexOf(p) === -1) queue.push(p)
    pageQueue = queue
    nextPage()
  }

  function nextPage() {
    if (galleryProc.running || galleryPending || pageQueue.length === 0) return
    var queue = pageQueue.slice()
    var p = queue.shift()
    pageQueue = queue
    if (pagesLoaded[p]) return nextPage()
    runGallery(p)
  }

  // The rows on screen (and a page either side) for paged sets
  function ensureVisible() {
    if (!paged) return
    var x = Style.space(20)
    var first = galleryList.indexAt(x, galleryList.contentY + 1)
    var last = galleryList.indexAt(x, galleryList.contentY + galleryList.height - 1)
    if (first < 0) first = 0
    if (last < 0) last = first + 20
    ensureRows(first, last + 10)
  }

  function placeholderRow(name) {
    // Sized like a typical font so jumping lands close to the right place
    return { font: name, art: "", codes: "", cols: fontSet === "ttf" ? 60 : 90,
             rows: fontSet === "ttf" ? Math.max(2, Number(draft.ttfRows) || 8) : 10,
             error: "", subtitle: "", pending: true }
  }

  function entryRow(g) {
    var subtitle = g.name && g.type ? g.name + " · " + g.type : (g.name || "")
    return { font: g.font, art: g.art || "", codes: g.codes || "", cols: g.cols || 1, rows: g.rows || 1,
             error: g.error || "", subtitle: subtitle, pending: false }
  }

  // Rich text for a TheDraw colour font from its rows and run-length codes
  // ("<fg hex or .><bg 0-7><length>" runs, one line per row)
  function codesToHtml(art, codes) {
    if (!codes) return ""
    var rows = art.split("\n")
    var codeRows = codes.split("\n")
    var out = []
    for (var r = 0; r < rows.length; r++) {
      var line = rows[r]
      var runs = (codeRows[r] || "").split(" ")
      var pos = 0
      var html = ""
      for (var i = 0; i < runs.length; i++) {
        var run = runs[i]
        if (run.length < 3) continue
        var n = parseInt(run.substring(2), 10)
        var text = line.substring(pos, pos + n)
          .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;")
        pos += n
        var style = (run[0] !== "." ? "color:" + dosColors[parseInt(run[0], 16)] + ";" : "")
          + (run[1] !== "0" ? "background-color:" + dosColors[parseInt(run[1], 10)] + ";" : "")
        html += style ? "<span style=\"" + style + "\">" + text + "</span>" : text
      }
      out.push(html)
    }
    return out.join("<br>")
  }

  function measure(list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].cols) continue  // TheDraw entries come measured
      var lines = list[i].art ? list[i].art.split("\n") : [""]
      var cols = 1
      for (var j = 0; j < lines.length; j++) cols = Math.max(cols, lines[j].length)
      list[i].cols = cols
      list[i].rows = lines.length
    }
    return list
  }

  function loadGallery(raw) {
    var list
    try {
      list = JSON.parse(raw)
    } catch (e) {
      showMessage("Could not render the gallery", true)
      return
    }
    if (!Array.isArray(list)) {
      // A TheDraw or system font page; a listing from before the latest
      // change is dropped
      if (galleryProcGen !== galleryGen) return
      var items = measure(list.items || [])
      var offset = list.offset || 0
      if (list.names) {
        loadListing(list.names, items)
      } else {
        for (var k = 0; k < items.length && offset + k < displayModel.count; k++)
          displayModel.set(offset + k, entryRow(items[k]))
        var loaded = Object.assign({}, pagesLoaded)
        loaded[offset] = true
        pagesLoaded = loaded
      }
      return
    }
    gallery = measure(list)
    galleryLoaded = true
    rebuildDisplay(false)
  }

  function rebuildDisplay(resetSelection) {
    var keep = draft.source !== "image" ? draft.font : (focusedEntry ? focusedEntry.font : "")
    var q = filterText.toLowerCase()
    displayModel.clear()
    var next = -1
    for (var i = 0; i < gallery.length; i++) {
      var g = gallery[i]
      if (q && g.font.toLowerCase().indexOf(q) === -1 && String(g.name || "").toLowerCase().indexOf(q) === -1) continue
      if (g.font === keep) next = displayModel.count
      displayModel.append(entryRow(g))
    }
    refreshFontNames()
    selectedIndex = resetSelection || next < 0 ? 0 : next
    Qt.callLater(function() {
      if (displayModel.count > 0) galleryList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
    requestPreview()
  }

  // A paged set's first page: a row for every name, the first page drawn
  function loadListing(names, items) {
    var keep = draft.source !== "image" ? draft.font : ""
    pageTotal = names.length
    pagesLoaded = ({ 0: true })
    gallery = items
    displayModel.clear()
    var next = -1
    for (var i = 0; i < names.length; i++) {
      if (names[i] === keep) next = i
      displayModel.append(i < items.length ? entryRow(items[i]) : placeholderRow(names[i]))
    }
    fontNames = names
    galleryLoaded = true
    selectedIndex = next < 0 ? 0 : next
    Qt.callLater(function() {
      if (displayModel.count > 0) galleryList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      root.ensureVisible()
    })
    requestPreview()
  }

  function refreshFontNames() {
    var names = []
    for (var i = 0; i < displayModel.count; i++) names.push(displayModel.get(i).font)
    fontNames = names
  }

  function loadImages(raw) {
    try {
      images = JSON.parse(raw)
    } catch (e) {
      images = []
    }
    rebuildImages()
  }

  function rebuildImages() {
    imagesModel.clear()
    var q = filterText.toLowerCase()
    var next = -1
    for (var i = 0; i < images.length; i++) {
      var im = images[i]
      if (q && (im.dir + "/" + im.name).toLowerCase().indexOf(q) === -1) continue
      if (im.path === draft.image) next = imagesModel.count
      imagesModel.append({ path: im.path, name: im.name, dir: im.dir })
    }
    imageIndex = next
  }

  function loadSaved(raw) {
    try {
      saved = JSON.parse(raw)
    } catch (e) {
      saved = []
    }
    savedLoaded = true
    rebuildSaved()
  }

  function rebuildSaved() {
    savedModel.clear()
    var q = filterText.toLowerCase()
    for (var i = 0; i < saved.length; i++) {
      var e = saved[i]
      if (q && (e.name + " " + (e.config.font || "") + " " + (e.config.text || "")).toLowerCase().indexOf(q) === -1) continue
      savedModel.append({ entryId: e.id, name: e.name, kind: e.kind, at: e.at, art: e.text || "", html: e.html || "",
                          cols: e.cols || 1, rows: e.rows || 1, ink: e.foreground || "", error: e.error || "",
                          index0: i })
    }
    if (savedIndex >= savedModel.count) savedIndex = savedModel.count - 1
  }

  function setFilter(text) {
    filterText = text
    if (fontSet === "image") rebuildImages()
    else if (fontSet === "saved") rebuildSaved()
    else if (fontSet === "tdf" || fontSet === "ttf") requestGallery()  // filtered by the CLI, page by page
    else rebuildDisplay(true)
  }

  function move(delta) {
    if (fontSet === "image") {
      if (imagesModel.count === 0) return
      // The grid moves by rows on ↑↓
      var step = delta * Math.max(1, imageGrid.columns)
      chooseImage(Math.max(0, Math.min(imagesModel.count - 1, (imageIndex < 0 ? 0 : imageIndex + step))))
      return
    }
    if (fontSet === "saved") {
      if (savedModel.count === 0) return
      useSaved(Math.max(0, Math.min(savedModel.count - 1, (savedIndex < 0 ? 0 : savedIndex + delta))))
      return
    }
    if (displayModel.count === 0) return
    selectedIndex = Math.max(0, Math.min(displayModel.count - 1, selectedIndex + delta))
    galleryList.positionViewAtIndex(selectedIndex, ListView.Contain)
    pickFocusedFont()
  }

  function pageStep() {
    return Math.max(1, Math.floor(galleryList.height / Style.space(90)))
  }

  // Picking a font (click or ↑↓) makes it the boot art right away
  function pickFocusedFont() {
    if (!fontMode || !focusedEntry) return
    if (draft.font === focusedEntry.font && draft.source === "text") return
    var next = Object.assign({}, draft)
    next.font = focusedEntry.font
    next.source = "text"
    draft = next
    draftEdited()
  }

  function chooseImage(index) {
    if (index < 0 || index >= imagesModel.count) return
    imageIndex = index
    imageGrid.positionViewAtIndex(index, GridView.Contain)
    setImage(imagesModel.get(index).path)
  }

  function setImage(path) {
    var next = Object.assign({}, draft)
    next.image = path
    next.source = "image"
    draft = next
    imagePathField.text = path
    draftEdited()
  }

  // Load a library entry into the draft
  function useSaved(index) {
    if (index < 0 || index >= savedModel.count) return
    savedIndex = index
    savedList.positionViewAtIndex(index, ListView.Contain)
    var e = saved[savedModel.get(index).index0]
    if (!e) return
    var next = Object.assign({}, draft, e.config)
    loadDraft(next)
    settingsTab = next.source === "image" ? "image" : "text"
    draftEdited()
    showMessage("Loaded “" + e.name + "”. Apply to boot to install it.", false)
  }

  function deleteSaved(id) {
    if (confirmDelete !== id) {
      confirmDelete = id
      return
    }
    confirmDelete = ""
    savedEditProc.command = [root.cli, "saved", "rm", id]
    savedEditProc.running = true
  }

  function startNaming() {
    if (needsEffect) {
      showMessage("Pick at least one intro effect on the Animation tab first", true)
      return
    }
    naming = true
    var suggestion = draft.source === "image" ? String(draft.image || "").replace(/^.*\//, "")
      : String(draft.text || "").split("\n")[0] + " · " + draft.font
    nameField.text = suggestion
    Qt.callLater(function() { nameField.forceActiveFocus(); nameField.selectAll() })
  }

  function saveToLibrary(name) {
    if (!String(name).trim() || savedEditProc.running) return
    naming = false
    autosaveTimer.stop()
    savedEditProc.command = [root.cli, "saved", "add", "--name", String(name).trim(), "--config-json", JSON.stringify(draft)]
    savedEditProc.running = true
    showMessage("Saved “" + String(name).trim() + "” to your library", false)
    searchField.forceActiveFocus()
  }

  function showMessage(text, isError) {
    message = text
    messageIsError = !!isError
    messageTimer.restart()
  }

  // ---------------------------------------------------------------- preview

  // The preview shows what the left pane focuses: a font with the text, or
  // the draft's image, or the draft as loaded from the library
  function previewConfig() {
    var c = Object.assign({}, draft)
    if (fontMode) {
      c.source = "text"
      if (focusedEntry) c.font = focusedEntry.font
    } else if (fontSet === "image") {
      c.source = "image"
    }
    return c
  }

  function requestPreview() {
    if (!status) return
    previewTimer.restart()
  }

  function runPreview() {
    var c = previewConfig()
    if (c.source === "image" && !c.image) {
      previewArt = null
      previewError = "Pick an image on the left, or paste a path."
      return
    }
    var key = JSON.stringify(c)
    if (previewProc.running) {
      previewPending = true
      return
    }
    previewPending = false
    previewKey = key
    previewProc.command = [root.cli, "render", "--json", "--config-json", key]
    previewProc.running = true
    // A playing intro follows the art
    if (animPlaying || animLoading) animTimer.restart()
  }

  // The intro the ▶ button plays: the last one tried, else the first chosen
  function playEffect() {
    var effects = draft.effects || []
    return animEffect || effects[0] || "decrypt"
  }

  function playAnimation(effect) {
    animEffect = effect
    if (animProc.running) return
    animLoading = true
    var c = previewConfig()
    c.style = "animated"
    if (!c.effects || c.effects.length === 0) c.effects = [effect]
    animProc.command = [root.cli, "frames", effect, "--config-json", JSON.stringify(c)]
    animProc.running = true
  }

  function stopAnimation() {
    animPlaying = false
    animLoading = false
    anim = null
    frameTimer.stop()
  }

  // ---------------------------------------------------------------- actions

  function importTaag(url) {
    if (!url || saveProc.running) return
    saveProc.command = [root.cli, "set", "--config-json", JSON.stringify(draft), "--taag", url]
    saveProc.running = true
    taagField.text = ""
  }

  function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  function inTerminal(args) {
    var cmd = [root.cli].concat(args).map(shellQuote).join(" ")
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", cmd])
  }

  function applyToBoot() {
    if (needsEffect) {
      settingsTab = "boot"
      showMessage("Pick at least one intro effect, or switch to Static", true)
      return
    }
    inTerminal(["apply", "--config-json", JSON.stringify(draft)])
    root.dismiss()
  }

  function exportGif() {
    if (needsEffect) {
      settingsTab = "boot"
      showMessage("Pick at least one intro effect, or switch to Static", true)
      return
    }
    // Build the frames, then open the first intro (or the still) in the image viewer
    var effects = draft.effects || []
    var first = draft.style === "animated" && effects.length ? effects[0] : ""
    var json = JSON.stringify(draft)
    var cmd = [root.cli, "set", "--config-json", json].map(shellQuote).join(" ") + " >/dev/null && "
      + [root.cli, "preview"].concat(first ? [first] : []).map(shellQuote).join(" ")
      + " | tail -n 1 | xargs -r -d '\\n' xdg-open"
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", cmd])
    root.dismiss()
  }

  function fetchTdf() {
    inTerminal(["tdf", "fetch"])
    root.dismiss()
  }

  function fetchFonts() {
    inTerminal(["fonts", "fetch"])
    root.dismiss()
  }

  function restore() {
    inTerminal(["restore"])
    root.dismiss()
  }

  function formatDate(iso) {
    var d = new Date(iso)
    if (isNaN(d.getTime())) return ""
    return Qt.formatDateTime(d, "MMM d, h:mm ap")
  }

  onSelectedIndexChanged: requestPreview()

  ListModel { id: displayModel }
  ListModel { id: imagesModel }
  ListModel { id: savedModel }

  Timer {
    id: galleryTimer
    interval: 300
    onTriggered: root.runGallery()
  }

  Timer {
    id: previewTimer
    interval: 90
    onTriggered: root.runPreview()
  }

  Timer {
    id: autosaveTimer
    interval: 800
    onTriggered: root.flushDraft()
  }

  Timer {
    id: messageTimer
    interval: 7000
    onTriggered: if (!root.messageIsError) root.message = ""
  }

  // Re-request the intro once the art settles
  Timer {
    id: animTimer
    interval: 450
    onTriggered: if (root.animEffect) root.playAnimation(root.animEffect)
  }

  // 50 fps like Plymouth; after the intro the hold highlight loops
  Timer {
    id: frameTimer
    interval: 20
    repeat: true
    onTriggered: {
      if (!root.anim) return stop()
      var next = root.animFrame + 1
      if (next >= root.anim.frames.length) {
        if (root.anim.hold >= root.anim.frames.length || root.anim.hold <= 0) {
          root.animFrame = root.anim.frames.length - 1
          return stop()
        }
        next = root.anim.hold
      }
      root.animFrame = next
    }
  }

  Process {
    id: statusProc
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.status = data
          var first = root.gallery.length === 0 && root.images.length === 0
          if (first && root.fontSet !== "saved") {
            var f = String(data.config.font).toLowerCase()
            root.fontSet = data.config.source === "image" ? "image"
              : f.indexOf("tdf ") === 0 ? "tdf" : f.indexOf("ttf ") === 0 ? "ttf" : "figlet"
            root.settingsTab = data.config.source === "image" ? "image" : "text"
          }
          root.loadDraft(data.config)
          if (data.error) root.showMessage(data.error, true)
          if (first) {
            if (root.fontSet === "image") imagesProc.running = true
            else root.runGallery()
          } else {
            root.requestGallery()
          }
          root.requestPreview()
        } catch (e) {
          root.showMessage("Could not read omascii status", true)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text).trim()) root.showMessage(String(text).trim().replace(/^omascii:\s*/, ""), true)
    }
  }

  Process {
    id: galleryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadGallery(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text).trim()) root.showMessage(String(text).trim().replace(/^omascii:\s*/, ""), true)
    }
    onExited: {
      if (root.galleryPending) root.runGallery()
      else root.nextPage()
    }
  }

  Process {
    id: imagesProc
    command: [root.cli, "images", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadImages(text)
    }
  }

  Process {
    id: savedProc
    command: [root.cli, "saved", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadSaved(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text).trim()) root.showMessage(String(text).trim().replace(/^omascii:\s*/, ""), true)
    }
  }

  // saved add / rm, then reload the library
  Process {
    id: savedEditProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text).trim()) root.showMessage(String(text).trim().replace(/^omascii:\s*/, ""), true)
    }
    onExited: function(code) {
      root.refreshSaved()
      if (code === 0) root.refreshStatus()
    }
  }

  Process {
    id: previewProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!String(text).trim()) return
        try {
          root.previewArt = JSON.parse(text)
          root.previewError = ""
        } catch (e) {
          root.previewError = "Could not render the preview"
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text).trim()
        if (err) {
          root.previewError = err.replace(/^omascii:\s*/, "")
          root.previewArt = null
        }
      }
    }
    onExited: if (root.previewPending) root.runPreview()
  }

  Process {
    id: animProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.animLoading = false
        try {
          var data = JSON.parse(text)
          if (!data.frames || !data.frames.length) return
          root.anim = data
          root.animFrame = 0
          root.animPlaying = true
          frameTimer.restart()
        } catch (e) {
          root.animPlaying = false
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text).trim()
        if (err) {
          root.animLoading = false
          root.showMessage(err.replace(/^omascii:\s*/, ""), true)
        }
      }
    }
  }

  // TAAG imports
  Process {
    id: saveProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text).trim()
        if (err) root.showMessage(err.replace(/^omascii:\s*/, ""), true)
        else root.showMessage("Imported the TAAG link", false)
      }
    }
    onExited: function(code) { if (code === 0) root.refreshStatus() }
  }

  // Monospace cell proportions, for sizing art to fit
  FontMetrics {
    id: mono
    font.family: root.monoFont
    font.pixelSize: 100
  }
  readonly property real advance: mono.averageCharacterWidth > 0 ? mono.averageCharacterWidth / 100 : 0.6
  readonly property real lineRatio: mono.height > 0 ? mono.height / 100 : 1.3

  function fitPixelSize(cols, rows, w, h, cap) {
    var byWidth = w / Math.max(1, cols * advance)
    var byHeight = h > 0 ? h / Math.max(1, rows * lineRatio) : cap
    return Math.max(2, Math.min(cap, byWidth, byHeight))
  }

  // ---------------------------------------------------------------- controls
  // Inline components don't see this file's ids, so their colours come from
  // the [menu] tokens.

  // A small bold caption over a setting
  component Caption: Text {
    color: Qt.darker(Commons.Color.menu.text, 1.3)
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  // A one-line explanation under a setting
  component Hint: Text {
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    color: Commons.Color.menu.text
    opacity: 0.55
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
  }

  // A caption over a switch, like the other settings
  component LabeledToggle: Column {
    id: lt
    property string label: ""
    property bool checked: false
    signal toggled()
    spacing: Style.spacing.labelGap
    Caption { text: lt.label }
    ToggleSwitch {
      checked: lt.checked
      foreground: Commons.Color.menu.text
      onToggled: lt.toggled()
    }
  }

  // One option: a radio dot (pick one) or a checkbox (pick many), an
  // optional colour swatch, the label and an optional ▶ to preview it
  component Chip: BorderSurface {
    id: chip
    property string text: ""
    property bool selected: false
    property bool multi: false
    property string swatch: ""
    property bool playable: false
    property bool playing: false
    property string tip: ""
    signal clicked()
    signal play()

    readonly property color ink: Commons.Color.menu.text
    readonly property bool hot: chipMouse.containsMouse

    implicitWidth: chipRow.implicitWidth + Style.space(18)
    implicitHeight: Math.max(Style.space(30), chipRow.implicitHeight + Style.space(10))
    radius: Style.cornerRadius
    color: selected ? Style.selectedFillFor(ink, Commons.Color.accent)
      : (hot ? Style.hoverFillFor(ink, Commons.Color.accent) : "transparent")
    borderSpec: Border.controlSpec(selected ? "selected" : (hot ? "hover-cursor" : "normal"), ink, Commons.Color.accent)

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: Style.space(7)

      // Checkbox or radio mark
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(14)
        height: width
        radius: chip.multi ? Math.max(2, Style.cornerRadius / 3) : width / 2
        color: chip.selected && chip.multi ? Commons.Color.accent : "transparent"
        border.width: Math.max(1, Style.space(1.5))
        border.color: chip.selected ? Commons.Color.accent : Qt.rgba(chip.ink.r, chip.ink.g, chip.ink.b, 0.5)
        Text {
          anchors.centerIn: parent
          visible: chip.selected && chip.multi
          text: "✓"
          color: Commons.Color.menu.background
          font.pixelSize: parent.height * 0.85
          font.bold: true
        }
        Rectangle {
          anchors.centerIn: parent
          visible: chip.selected && !chip.multi
          width: parent.width * 0.5
          height: width
          radius: width / 2
          color: Commons.Color.accent
        }
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: chip.swatch !== ""
        width: Style.space(14)
        height: width
        radius: Math.max(2, Style.cornerRadius / 3)
        color: chip.swatch || "transparent"
        border.width: 1
        border.color: Qt.rgba(chip.ink.r, chip.ink.g, chip.ink.b, 0.35)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: chip.text
        color: chip.ink
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
      }

      // Preview this effect without choosing it
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: chip.playable
        text: chip.playing ? "■" : "▶"
        color: playMouse.containsMouse || chip.playing ? Commons.Color.accent : Qt.rgba(chip.ink.r, chip.ink.g, chip.ink.b, 0.55)
        font.pixelSize: Style.font.bodySmall
        leftPadding: Style.space(4)
        MouseArea {
          id: playMouse
          anchors.fill: parent
          anchors.margins: -Style.space(5)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: chip.play()
        }
      }
    }
  }

  // Pick one: a caption over a wrapping row of radio chips. Options are
  // strings or {value, label, swatch}.
  component ChoiceChips: Column {
    id: cc
    property string label: ""
    property string hint: ""
    property var options: []
    property string value: ""
    signal picked(string value)
    spacing: Style.spacing.labelGap

    Caption { visible: cc.label !== ""; text: cc.label }
    Flow {
      width: cc.width
      spacing: Style.space(6)
      Repeater {
        model: cc.options
        Chip {
          required property var modelData
          readonly property bool isObject: modelData !== null && typeof modelData === "object"
          readonly property string optionValue: isObject ? String(modelData.value) : String(modelData)
          text: isObject && modelData.label !== undefined ? String(modelData.label) : optionValue
          swatch: isObject && modelData.swatch ? String(modelData.swatch) : ""
          selected: optionValue === cc.value
          onClicked: cc.picked(optionValue)
        }
      }
    }
    Hint { visible: cc.hint !== ""; width: cc.width; text: cc.hint }
  }

  // Pick many: a caption with Select all / Clear over checkbox chips
  component CheckChips: Column {
    id: ck
    property string label: ""
    property var options: []
    property var values: []
    property bool playable: false
    property string playing: ""
    signal changed(var values)
    signal play(string value)
    spacing: Style.spacing.labelGap

    function has(v) {
      for (var i = 0; i < ck.values.length; i++) if (String(ck.values[i]) === v) return true
      return false
    }
    // Keeps the options' order
    function toggle(v) {
      var out = []
      var on = !has(v)
      for (var i = 0; i < ck.options.length; i++) {
        var o = String(ck.options[i])
        if (o === v ? on : has(o)) out.push(o)
      }
      ck.changed(out)
    }

    Row {
      spacing: Style.space(10)
      Caption {
        anchors.verticalCenter: parent.verticalCenter
        text: ck.label + "  ·  " + ck.values.length + " of " + ck.options.length
      }
      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: "Select all"
        bordered: true
        foreground: Commons.Color.menu.text
        fontSize: Style.font.caption
        onClicked: ck.changed(ck.options.map(function(o) { return String(o) }))
      }
      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: "Clear"
        bordered: true
        foreground: Commons.Color.menu.text
        fontSize: Style.font.caption
        onClicked: ck.changed([])
      }
    }
    Flow {
      width: ck.width
      spacing: Style.space(6)
      Repeater {
        model: ck.options
        Chip {
          required property var modelData
          readonly property string optionValue: String(modelData)
          multi: true
          text: optionValue
          selected: ck.has(optionValue)
          playable: ck.playable
          playing: ck.playing === optionValue
          onClicked: ck.toggle(optionValue)
          onPlay: ck.play(optionValue)
        }
      }
    }
  }

  // A wide scrollbar for long lists: click or drag anywhere on it to jump
  // there. Letter marks show where each initial starts, and hovering shows
  // the name at that spot.
  component JumpBar: Item {
    id: jb
    property var view: null          // the ListView it drives
    property var labels: []          // one name per row
    readonly property int count: labels.length
    readonly property color ink: Commons.Color.menu.text

    // The rows in view, for the thumb
    readonly property int firstVisible: {
      if (!view || count === 0) return 0
      var y = view.contentY
      var i = view.indexAt(Style.space(20), y + 1)
      return i < 0 ? view.indexAt(Style.space(20), y + view.spacing + 1) : i
    }
    readonly property int lastVisible: {
      if (!view || count === 0) return 0
      var y = view.contentY + view.height
      var i = view.indexAt(Style.space(20), y - 1)
      return i < 0 ? (view.atYEnd ? count - 1 : view.indexAt(Style.space(20), y - view.spacing - 1)) : i
    }

    // The first row of each initial, spaced so the letters don't overlap
    readonly property var marks: {
      var out = []
      var lastY = -1000
      var minGap = Style.font.caption * 1.25
      var prev = ""
      for (var i = 0; i < labels.length; i++) {
        var name = String(labels[i]).replace(/^(tdf|ttf)\s+/i, "")
        var c = name.charAt(0).toUpperCase()
        if (!/[A-Z]/.test(c)) c = "#"
        if (c === prev) continue
        prev = c
        var y = i / count * jb.height
        if (y - lastY < minGap) continue
        out.push({ letter: c, y: y })
        lastY = y
      }
      return out
    }

    property int hoverIndex: -1

    function indexAtY(y) {
      return Math.max(0, Math.min(count - 1, Math.floor(y / Math.max(1, height) * count)))
    }

    function jump(y) {
      if (!view || count === 0) return
      var i = indexAtY(y)
      hoverIndex = i
      view.positionViewAtIndex(i, ListView.Beginning)
    }

    width: Style.space(26)
    visible: count > 1

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Qt.rgba(jb.ink.r, jb.ink.g, jb.ink.b, jumpMouse.containsMouse || jumpMouse.pressed ? 0.10 : 0.05)
    }

    // Where the list is now
    Rectangle {
      x: Style.space(3)
      width: parent.width - Style.space(6)
      y: jb.count ? jb.firstVisible / jb.count * jb.height : 0
      height: Math.min(jb.height - y, Math.max(Style.space(18),
              jb.count ? (Math.max(jb.lastVisible, jb.firstVisible) - jb.firstVisible + 1) / jb.count * jb.height : 0))
      radius: Style.cornerRadius
      color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, jumpMouse.pressed ? 0.55 : 0.35)
    }

    Repeater {
      model: jb.marks
      Text {
        required property var modelData
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(jb.height - height, modelData.y)
        text: modelData.letter
        color: jb.ink
        opacity: 0.75
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    MouseArea {
      id: jumpMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      preventStealing: true
      onPressed: function(mouse) { jb.jump(mouse.y) }
      onPositionChanged: function(mouse) {
        if (pressed) jb.jump(mouse.y)
        else jb.hoverIndex = jb.indexAtY(mouse.y)
      }
      onExited: if (!pressed) jb.hoverIndex = -1
      onReleased: if (!containsMouse) jb.hoverIndex = -1
      // Wheel over the bar still scrolls the list
      onWheel: function(wheel) {
        if (jb.view) jb.view.flick(0, wheel.angleDelta.y * 8)
      }
    }

    // The name at the pointer, beside the bar
    Rectangle {
      visible: jb.hoverIndex >= 0 && (jumpMouse.containsMouse || jumpMouse.pressed)
      anchors.right: parent.left
      anchors.rightMargin: Style.space(6)
      y: Math.max(0, Math.min(jb.height - height, jumpMouse.mouseY - height / 2))
      width: bubbleText.implicitWidth + Style.space(16)
      height: bubbleText.implicitHeight + Style.space(8)
      radius: Style.cornerRadius
      color: Commons.Color.tooltip.background
      border.width: 1
      border.color: Commons.Color.accent
      Text {
        id: bubbleText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: jb.hoverIndex >= 0 && jb.hoverIndex < jb.count
          ? jb.labels[jb.hoverIndex] + "   " + (jb.hoverIndex + 1) + "/" + jb.count : ""
        color: Commons.Color.tooltip.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }
  }

  // ---------------------------------------------------------------- UI

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-omascii"

    // Clicking outside no longer closes the designer: use ✕ or Esc
    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(1560), panel.width - Style.gapsOut * 4)
      height: Math.min(Style.space(1020), panel.height - Style.gapsOut * 4)
      radius: Style.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.pad

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.naming) {
              root.naming = false
              searchField.forceActiveFocus()
            } else if (root.animPlaying) {
              root.stopAnimation()
            } else if (root.filterText) {
              searchField.text = ""
            } else {
              root.dismiss()
            }
            event.accepted = true
          } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                     && (event.modifiers & Qt.ControlModifier)) {
            root.applyToBoot()
            event.accepted = true
          } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            if (root.animPlaying) root.stopAnimation()
            else root.playAnimation(root.playEffect())
            event.accepted = true
          } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
            root.startNaming()
            event.accepted = true
          }
        }

        // ---------- Header: title, the three steps, close ----------
        Item {
          id: titleBar
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: Math.max(title.implicitHeight, closeButton.height)

          Text {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "omascii"
            color: root.foreground
            font.family: root.monoFont
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Text {
            anchors.left: title.right
            anchors.leftMargin: root.gap * 1.5
            anchors.right: closeButton.left
            anchors.rightMargin: root.gap
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: "Boot screen designer   ①  Type your text and pick a font, image or saved screen   "
              + "②  Fine-tune it in the tabs   ③  Save it to your library, then Apply to boot"
            color: root.foreground
            opacity: 0.6
            font.family: root.uiFont
            font.pixelSize: Style.font.bodySmall
          }

          Button {
            id: closeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "✕  Close"
            tooltipText: "Close (Esc). Your settings are kept."
            bordered: true
            foreground: root.foreground
            onClicked: root.dismiss()
          }
        }

        // ---------- Text and search ----------
        Row {
          id: header
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: titleBar.bottom
          anchors.topMargin: root.gap
          spacing: root.gap

          Column {
            width: (header.width - header.spacing) * 0.55
            spacing: Style.spacing.labelGap
            Caption { text: "Your text   (type \\n for a new line)" }
            TextField {
              id: textField
              width: parent.width
              placeholderText: "e.g. HyprStack"
              foreground: root.foreground
              font.family: root.monoFont
              font.pixelSize: Style.font.title
              onTextEdited: root.setDraft("text", text.replace(/\\n/g, "\n"))
              Keys.onUpPressed: root.move(-1)
              Keys.onDownPressed: root.move(1)
            }
          }

          Column {
            width: (header.width - header.spacing) * 0.45
            spacing: Style.spacing.labelGap
            Caption {
              text: root.fontSet === "image" ? "Filter images" : root.fontSet === "saved" ? "Filter your library"
                : "Search fonts   (↑ ↓ to browse)"
            }
            TextField {
              id: searchField
              width: parent.width
              placeholderText: root.fontSet === "image" ? "Image name…"
                : root.fontSet === "saved" ? "Name, font or text…"
                : "Search " + (root.fontSet === "tdf" ? root.tdfCount : root.fontSet === "ttf" ? root.ttfCount
                               : (root.status ? root.status.fontCount : "")) + " fonts…"
              foreground: root.foreground
              font.pixelSize: Style.font.title
              onTextChanged: root.setFilter(text)
              Keys.onUpPressed: root.move(-1)
              Keys.onDownPressed: root.move(1)
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_PageDown) { root.move(root.pageStep()); event.accepted = true }
                else if (event.key === Qt.Key_PageUp) { root.move(-root.pageStep()); event.accepted = true }
              }
            }
          }
        }

        // ---------- Left: every font, TAAG "test all" style, images or the library ----------
        BorderSurface {
          id: galleryPane
          anchors.left: parent.left
          anchors.top: header.bottom
          anchors.topMargin: root.gap
          anchors.bottom: footer.top
          anchors.bottomMargin: root.gap
          width: parent.width * 0.46
          radius: Style.cornerRadius
          color: "transparent"
          borderSpec: Border.controlSpec("normal", root.foreground, Commons.Color.accent)

          Caption {
            id: sourceCaption
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Style.space(8)
            text: "① Pick the art from"
          }

          ButtonGroup {
            id: setSwitch
            anchors.left: parent.left
            anchors.top: sourceCaption.bottom
            anchors.leftMargin: Style.space(8)
            anchors.topMargin: Style.spacing.labelGap
            spacing: Style.space(6)
            options: [
              { value: "saved", label: "★ My boot screens · " + root.saved.length, tooltip: "Boot screens you saved or applied before" },
              { value: "figlet", label: "FIGlet · " + (root.status ? root.status.fontCount : ""), tooltip: "TAAG's FIGlet fonts" },
              { value: "tdf", label: "TheDraw · " + root.tdfCount, tooltip: "DOS colour fonts" },  // fonts, not files
              { value: "ttf", label: "System · " + root.ttfCount, tooltip: "Your installed fonts, drawn as pixels" },
              { value: "image", label: "Image", tooltip: "Turn a picture into ASCII art" }
            ]
            value: root.fontSet
            foreground: root.foreground
            fontSize: Style.font.bodySmall
            onChanged: function(v) { root.setFontSet(v) }
          }

          Hint {
            id: paneHint
            anchors.left: parent.left
            anchors.right: moreFonts.visible ? moreFonts.left : parent.right
            anchors.top: setSwitch.bottom
            anchors.margins: Style.space(8)
            text: root.fontSet === "saved" ? "Click a boot screen to load it, then Apply to boot. Save new ones with “Save to library”."
              : root.fontSet === "image" ? "Click an image to use it. Tune the conversion on the Image tab."
              : "Click a font (or use ↑ ↓) to use it. The preview on the right is what will boot."
          }

          Button {
            id: moreFonts
            anchors.right: parent.right
            anchors.verticalCenter: paneHint.verticalCenter
            anchors.rightMargin: Style.space(8)
            visible: root.fontSet === "figlet"
            text: root.status && root.status.extraFontCount ? "+" + root.status.extraFontCount + " extra" : "Get more fonts"
            tooltipText: "Download the xero/figlet-fonts collection (FIGlet and toilet fonts not in TAAG's set)"
            bordered: true
            foreground: root.foreground
            fontSize: Style.font.caption
            onClicked: root.fetchFonts()
          }

          JumpBar {
            id: fontJump
            z: 2
            anchors.right: parent.right
            anchors.top: galleryList.top
            anchors.bottom: galleryList.bottom
            anchors.rightMargin: Style.space(6)
            view: galleryList
            labels: root.fontMode ? root.fontNames : []
          }

          ListView {
            id: galleryList
            anchors.left: parent.left
            anchors.right: fontJump.visible ? fontJump.left : parent.right
            anchors.top: paneHint.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(6)
            visible: root.fontMode
            clip: true
            model: displayModel
            spacing: Style.space(4)
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600
            onContentYChanged: if (root.paged) visibleTimer.restart()
            onHeightChanged: if (root.paged) visibleTimer.restart()

            // Render the pages in view once scrolling settles
            Timer {
              id: visibleTimer
              interval: 120
              onTriggered: root.ensureVisible()
            }

            delegate: Rectangle {
              id: row
              required property int index
              required property string font
              required property string art
              required property string codes
              required property string subtitle
              readonly property string html: codes ? root.codesToHtml(art, codes) : ""
              required property int cols
              required property int rows
              required property string error
              required property bool pending

              readonly property bool hasCursor: index === root.selectedIndex
              readonly property bool inUse: root.draft.font === font && root.draft.source !== "image"
              readonly property real artSize: root.fitPixelSize(cols, rows, width - Style.space(20), 0, Style.space(13))

              width: galleryList.width
              // A row still rendering keeps roughly its final height
              height: nameText.height + (pending ? rows * artSize * root.lineRatio : artText.height) + Style.space(14)
              radius: Style.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Text {
                id: nameText
                x: Style.space(10)
                y: Style.space(5)
                width: parent.width - Style.space(20)
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: (row.inUse ? "✓ " : "") + row.font + (row.subtitle ? "  (" + row.subtitle + ")" : "")
                  + (row.inUse ? "  · in use" : "") + (row.pending ? "" : "   " + row.cols + "×" + row.rows)
                color: row.hasCursor ? root.selectedText : root.foreground
                opacity: row.hasCursor || row.inUse ? 1 : 0.6
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                id: artText
                x: Style.space(10)
                anchors.top: nameText.bottom
                anchors.topMargin: Style.space(3)
                // TheDraw colour fonts come as rich text spans in their own colours
                textFormat: row.html && !row.error ? Text.RichText : Text.PlainText
                text: row.error ? row.error
                  : row.pending ? "Rendering…"
                  : (row.html ? row.html : (row.art || "(nothing — try another layout)"))
                color: row.hasCursor ? root.selectedText : root.foreground
                opacity: row.pending ? 0.4 : 1
                font.family: root.monoFont
                font.pixelSize: row.artSize
                wrapMode: Text.NoWrap
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectedIndex = row.index
                  root.pickFocusedFont()
                }
              }
            }

            Column {
              anchors.centerIn: parent
              width: parent.width - Style.space(40)
              spacing: Style.space(12)
              visible: displayModel.count === 0
              readonly property bool noTdf: root.fontSet === "tdf" && root.galleryLoaded && root.tdfCount === 0

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: parent.noTdf
                  ? "No TheDraw fonts yet. Download the collection (about 1,200 fonts) into "
                    + (root.status ? root.status.tdf.dir : "~/.local/share/omascii/tdf")
                    + ", or add your own with: omascii fonts add <files>"
                  : (!root.galleryLoaded ? "Rendering every font…" : "No fonts match “" + root.filterText + "”")
                color: root.foreground
                opacity: 0.7
                font.family: root.uiFont
                font.pixelSize: Style.font.title
              }

              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: parent.noTdf
                text: "Download TheDraw fonts"
                tooltipText: "git clone the tdfiglet font collection in a terminal"
                bordered: true
                active: true
                foreground: root.foreground
                onClicked: root.fetchTdf()
              }
            }
          }

          // ----- The library: saved and previously applied boot screens
          ListView {
            id: savedList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: paneHint.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(6)
            visible: root.fontSet === "saved"
            clip: true
            model: savedModel
            spacing: Style.space(6)
            boundsBehavior: Flickable.StopAtBounds
            QQC.ScrollBar.vertical: QQC.ScrollBar {}

            delegate: BorderSurface {
              id: card2
              required property int index
              required property string entryId
              required property string name
              required property string kind
              required property string at
              required property string art
              required property string html
              required property int cols
              required property int rows
              required property string ink
              required property string error

              readonly property bool hasCursor: index === root.savedIndex
              width: savedList.width - Style.space(10)
              height: savedHead.height + savedArt.height + Style.space(22)
              radius: Style.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"
              borderSpec: Border.controlSpec(hasCursor ? "selected" : "normal", root.foreground, Commons.Color.accent)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.useSaved(card2.index)
              }

              Item {
                id: savedHead
                x: Style.space(10)
                y: Style.space(7)
                width: parent.width - Style.space(20)
                height: Math.max(savedName.implicitHeight, savedButtons.implicitHeight)

                Column {
                  anchors.left: parent.left
                  anchors.right: savedButtons.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  Text {
                    id: savedName
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: card2.name
                    color: card2.hasCursor ? root.selectedText : root.foreground
                    font.family: root.uiFont
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: (card2.kind === "applied" ? "Applied to boot " : "Saved ") + root.formatDate(card2.at)
                    color: card2.hasCursor ? root.selectedText : root.foreground
                    opacity: 0.6
                    font.family: root.uiFont
                    font.pixelSize: Style.font.caption
                  }
                }

                Row {
                  id: savedButtons
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)
                  Button {
                    text: "Load"
                    tooltipText: "Load into the designer"
                    bordered: true
                    foreground: card2.hasCursor ? root.selectedText : root.foreground
                    fontSize: Style.font.caption
                    onClicked: root.useSaved(card2.index)
                  }
                  Button {
                    text: root.confirmDelete === card2.entryId ? "Really delete?" : "Delete"
                    tooltipText: "Remove from the library (click twice)"
                    bordered: true
                    active: root.confirmDelete === card2.entryId
                    foreground: card2.hasCursor ? root.selectedText : root.foreground
                    fontSize: Style.font.caption
                    onClicked: root.deleteSaved(card2.entryId)
                  }
                }
              }

              Text {
                id: savedArt
                x: Style.space(10)
                anchors.top: savedHead.bottom
                anchors.topMargin: Style.space(6)
                textFormat: card2.html && !card2.error ? Text.RichText : Text.PlainText
                text: card2.error ? card2.error : (card2.html ? card2.html : (card2.art || " "))
                color: card2.error ? Commons.Color.urgent : (card2.ink || root.foreground)
                font.family: root.monoFont
                font.pixelSize: root.fitPixelSize(card2.cols, card2.rows, card2.width - Style.space(20), Style.space(140), Style.space(11))
                wrapMode: Text.NoWrap
              }
            }

            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(40)
              visible: savedModel.count === 0
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              text: !root.savedLoaded ? "Loading your boot screens…"
                : root.saved.length === 0
                  ? "No saved boot screens yet. Design one, then press “Save to library” (Ctrl+S). Boot screens you apply are added here too."
                  : "Nothing matches “" + root.filterText + "”"
              color: root.foreground
              opacity: 0.7
              font.family: root.uiFont
              font.pixelSize: Style.font.title
            }
          }

          // Images: a path field, then thumbnails of what was found
          TextField {
            id: imagePathField
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: paneHint.bottom
            anchors.margins: Style.space(8)
            visible: root.fontSet === "image"
            placeholderText: "Or paste an image path (png, jpg, gif, webp…) and press Enter"
            foreground: root.foreground
            onAccepted: if (text.trim()) root.setImage(text.trim())
          }

          GridView {
            id: imageGrid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: imagePathField.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(6)
            visible: root.fontSet === "image"
            clip: true
            model: imagesModel
            readonly property int columns: Math.max(1, Math.floor(width / Style.space(170)))
            cellWidth: Math.floor(width / columns)
            cellHeight: Math.round(cellWidth * 0.72)
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 400
            QQC.ScrollBar.vertical: QQC.ScrollBar {}

            delegate: Rectangle {
              id: tile
              required property int index
              required property string path
              required property string name
              required property string dir
              readonly property bool hasCursor: index === root.imageIndex
              width: imageGrid.cellWidth
              height: imageGrid.cellHeight
              radius: Style.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Image {
                id: thumb
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: tileName.top
                anchors.margins: Style.space(5)
                source: "file://" + tile.path
                sourceSize.width: 320
                sourceSize.height: 220
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectFit
              }

              Text {
                id: tileName
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(5)
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: (tile.hasCursor ? "✓ " : "") + tile.name
                color: tile.hasCursor ? root.selectedText : root.foreground
                opacity: tile.hasCursor ? 1 : 0.6
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.chooseImage(tile.index)
              }
            }

            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(40)
              visible: imagesModel.count === 0
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              text: root.images.length === 0
                ? "No images found in ~/Pictures, ~/Downloads or your backgrounds. Paste a path above."
                : "No images match “" + root.filterText + "”"
              color: root.foreground
              opacity: 0.7
              font.family: root.uiFont
              font.pixelSize: Style.font.title
            }
          }
        }

        // ---------- Right: live preview + settings ----------
        Item {
          id: side
          anchors.left: galleryPane.right
          anchors.leftMargin: root.gap
          anchors.right: parent.right
          anchors.top: header.bottom
          anchors.topMargin: root.gap
          anchors.bottom: footer.top
          anchors.bottomMargin: root.gap

          // Boot screen preview, in the boot colours
          Rectangle {
            id: previewBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(parent.height * 0.44)
            radius: Style.cornerRadius
            color: root.anim && root.animPlaying ? "#" + root.anim.background
              : (root.previewArt ? root.previewArt.background : Commons.Color.background)
            clip: true

            readonly property bool showingAnim: !!root.anim && root.animPlaying

            Text {
              id: previewName
              anchors.left: parent.left
              anchors.right: playRow.left
              anchors.top: parent.top
              anchors.margins: Style.space(10)
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: {
                var head = "BOOT PREVIEW  ·  "
                if (root.fontSet === "image" || (root.fontSet === "saved" && root.draft.source === "image"))
                  return head + (root.draft.image ? String(root.draft.image).replace(/^.*\//, "") : "no image yet")
                if (root.fontMode && root.focusedEntry) return head + root.focusedEntry.font
                return head + (root.draft.font || "")
              }
              color: Commons.Color.foreground
              opacity: 0.6
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Row {
              id: playRow
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(6)
              spacing: Style.space(6)

              Button {
                text: root.animLoading ? "Loading " + root.playEffect() + "…"
                  : (root.animPlaying ? "■ Stop" : "▶ Play intro: " + root.playEffect())
                tooltipText: "Play the boot animation here (Ctrl+P). Pick which one with ▶ on the Animation tab."
                bordered: true
                foreground: Commons.Color.foreground
                onClicked: root.animPlaying ? root.stopAnimation() : root.playAnimation(root.playEffect())
              }
            }

            // The art, live with every setting
            Text {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: Style.space(14)
              visible: !previewBox.showingAnim && !!root.previewArt
              readonly property bool rich: !!root.previewArt && root.previewArt.html !== ""
              textFormat: rich ? Text.RichText : Text.PlainText
              text: root.previewArt ? (rich ? root.previewArt.html : (root.previewArt.text || " ")) : ""
              color: root.previewArt ? root.previewArt.foreground : Commons.Color.accent
              font.family: root.monoFont
              font.pixelSize: root.previewArt
                ? root.fitPixelSize(root.previewArt.cols, root.previewArt.rows,
                                    previewBox.width - Style.space(40), previewBox.height - Style.space(80), Style.space(28))
                : 12
              wrapMode: Text.NoWrap
            }

            // The intro, frame by frame
            Text {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: Style.space(14)
              visible: previewBox.showingAnim
              textFormat: Text.RichText
              text: previewBox.showingAnim ? root.anim.frames[Math.min(root.animFrame, root.anim.frames.length - 1)] : ""
              color: root.previewArt ? root.previewArt.foreground : Commons.Color.accent
              font.family: root.monoFont
              font.pixelSize: root.anim
                ? root.fitPixelSize(root.anim.cols, root.anim.rows,
                                    previewBox.width - Style.space(20), previewBox.height - Style.space(60), Style.space(28))
                : 12
              wrapMode: Text.NoWrap
            }

            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(60)
              visible: !root.previewArt && !previewBox.showingAnim
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              text: root.previewError || "Rendering…"
              color: root.previewError && root.previewError.indexOf("Pick an image") !== 0 ? Commons.Color.urgent : Commons.Color.foreground
              opacity: 0.8
              font.family: root.uiFont
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              anchors.margins: Style.space(8)
              textFormat: Text.PlainText
              text: previewBox.showingAnim
                ? root.anim.effect + "  " + (root.animFrame + 1) + "/" + root.anim.frames.length
                  + (root.animFrame >= root.anim.hold && root.anim.hold > 0 ? "  (hold)" : "")
                : (root.previewArt ? root.previewArt.cols + "×" + root.previewArt.rows + " cells" : "")
              color: Commons.Color.foreground
              opacity: 0.45
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
            }
          }

          // ----- ② Settings: tabs over a scrolling page of option chips
          Caption {
            id: settingsCaption
            anchors.left: parent.left
            anchors.top: previewBox.bottom
            anchors.topMargin: root.gap
            text: "② Fine-tune"
          }

          ButtonGroup {
            id: tabs
            anchors.left: parent.left
            anchors.top: settingsCaption.bottom
            anchors.topMargin: Style.spacing.labelGap
            spacing: Style.space(6)
            options: [
              { value: "text", label: "Text layout" }, { value: "image", label: "Image" },
              { value: "style", label: "Colour & style" },
              { value: "boot", label: "Animation" + (root.needsEffect ? " ⚠" : "") }
            ]
            value: root.settingsTab
            foreground: root.foreground
            fontSize: Style.font.bodySmall
            onChanged: function(v) { root.settingsTab = v }
          }

          Flickable {
            id: settingsScroll
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabs.bottom
            anchors.topMargin: root.gap
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: settings.implicitHeight + Style.space(8)
            boundsBehavior: Flickable.StopAtBounds
            QQC.ScrollBar.vertical: QQC.ScrollBar { policy: settingsScroll.contentHeight > settingsScroll.height ? QQC.ScrollBar.AlwaysOn : QQC.ScrollBar.AsNeeded }

            Column {
              id: settings
              width: settingsScroll.width - Style.space(16)
              spacing: Style.space(14)

              // ----- Text: FIGlet layout, system font size, TAAG import
              Column {
                id: textTab
                width: parent.width
                spacing: Style.space(14)
                visible: root.settingsTab === "text"

                ChoiceChips {
                  width: parent.width
                  label: "Letter spacing, side to side (FIGlet fonts)"
                  options: root.status ? root.status.layouts.map(function(l) { return { value: l, label: root.layoutLabels[l] || l } }) : []
                  value: String(root.draft.hlayout || "")
                  onPicked: function(v) { root.setDraft("hlayout", v) }
                }

                ChoiceChips {
                  width: parent.width
                  label: "Line spacing, top to bottom (FIGlet fonts)"
                  hint: "Smushing squeezes letters together. Use Font default for one-column fonts such as Circle."
                  options: root.status ? root.status.layouts.map(function(l) { return { value: l, label: root.layoutLabels[l] || l } }) : []
                  value: String(root.draft.vlayout || "")
                  onPicked: function(v) { root.setDraft("vlayout", v) }
                }

                Flow {
                  width: parent.width
                  spacing: Style.space(20)
                  NumberField {
                    label: "Wrap at column (0 = never)"
                    from: 0
                    to: 400
                    stepSize: 10
                    value: Number(root.draft.width) || 0
                    foreground: root.foreground
                    onModified: function(v) { root.setDraft("width", v) }
                  }
                  LabeledToggle {
                    label: "Wrap only at spaces"
                    checked: !!root.draft.whitespaceBreak
                    onToggled: root.setDraft("whitespaceBreak", !root.draft.whitespaceBreak)
                  }
                  NumberField {
                    label: "System font height (rows)"
                    from: 2
                    to: 60
                    value: Number(root.draft.ttfRows) || 8
                    foreground: root.foreground
                    onModified: function(v) { root.setDraft("ttfRows", v) }
                  }
                }

                ChoiceChips {
                  width: parent.width
                  label: "System fonts are drawn with"
                  options: root.status ? root.status.charsets.filter(function(c) { return c !== "custom" })
                    .map(function(c) { return { value: c, label: root.charsetLabels[c] || c } }) : []
                  value: String(root.draft.ttfCharset || "quadrant")
                  onPicked: function(v) { root.setDraft("ttfCharset", v) }
                }

                Column {
                  width: parent.width
                  spacing: Style.spacing.labelGap
                  Caption { text: "Import from patorjk.com TAAG" }
                  TextField {
                    id: taagField
                    width: parent.width
                    placeholderText: "Paste a patorjk.com/software/taag link and press Enter"
                    foreground: root.foreground
                    onAccepted: root.importTaag(text)
                  }
                }
              }

              // ----- Image: how pixels become characters
              Column {
                id: imageTab
                width: parent.width
                spacing: Style.space(14)
                visible: root.settingsTab === "image"

                Hint {
                  width: parent.width
                  visible: root.draft.source !== "image"
                  text: "These apply when the art is an image. Pick one with Image on the left."
                }

                ChoiceChips {
                  width: parent.width
                  label: "Draw the image with"
                  options: root.status ? root.status.charsets.map(function(c) { return { value: c, label: root.charsetLabels[c] || c } }) : []
                  value: String(root.draft.charset || "ascii")
                  onPicked: function(v) { root.setDraft("charset", v) }
                }

                TextField {
                  width: parent.width
                  visible: root.draft.charset === "custom"
                  placeholderText: "Custom ramp, darkest first, e.g.  .:oO@"
                  text: String(root.draft.chars || "")
                  foreground: root.foreground
                  onTextEdited: root.setDraft("chars", text)
                }

                Flow {
                  width: parent.width
                  spacing: Style.space(20)
                  NumberField {
                    label: "Width (columns)"
                    from: 8
                    to: 400
                    stepSize: 5
                    value: Number(root.draft.imageWidth) || 80
                    foreground: root.foreground
                    onModified: function(v) { root.setDraft("imageWidth", v) }
                  }
                  NumberField {
                    label: "Contrast %"
                    from: 0
                    to: 500
                    stepSize: 10
                    value: Math.round((Number(root.draft.contrast) || 1) * 100)
                    foreground: root.foreground
                    onModified: function(v) { root.setDraft("contrast", v / 100) }
                  }
                  NumberField {
                    label: "Brightness %"
                    from: 0
                    to: 500
                    stepSize: 10
                    value: Math.round((Number(root.draft.brightness) || 1) * 100)
                    foreground: root.foreground
                    onModified: function(v) { root.setDraft("brightness", v / 100) }
                  }
                  NumberField {
                    label: "Threshold %"
                    from: 0
                    to: 100
                    stepSize: 5
                    value: Number(root.draft.threshold) || 0
                    foreground: root.foreground
                    onModified: function(v) { root.setDraft("threshold", v) }
                  }
                }

                Flow {
                  width: parent.width
                  spacing: Style.space(24)
                  LabeledToggle {
                    label: "Keep image colours"
                    checked: !!root.draft.imageColors
                    onToggled: root.setDraft("imageColors", !root.draft.imageColors)
                  }
                  LabeledToggle {
                    label: "Invert"
                    checked: !!root.draft.invert
                    onToggled: root.setDraft("invert", !root.draft.invert)
                  }
                  LabeledToggle {
                    label: "Dither"
                    checked: !!root.draft.dither
                    onToggled: root.setDraft("dither", !root.draft.dither)
                  }
                  LabeledToggle {
                    label: "Auto levels"
                    checked: !!root.draft.normalize
                    onToggled: root.setDraft("normalize", !root.draft.normalize)
                  }
                }
              }

              // ----- Style: applied to any font or image
              Column {
                id: styleTab
                width: parent.width
                spacing: Style.space(14)
                visible: root.settingsTab === "style"

                ChoiceChips {
                  width: parent.width
                  label: "Colouring"
                  options: root.status ? root.status.colorModes : []
                  value: String(root.draft.colorMode || "solid")
                  onPicked: function(v) { root.setDraft("colorMode", v) }
                }

                ChoiceChips {
                  width: parent.width
                  visible: root.draft.colorMode === "palette"
                  label: "Palette"
                  options: {
                    var stops = root.status && root.status.paletteStops ? root.status.paletteStops : ({})
                    return (root.status ? root.status.palettes || [] : []).map(function(n) {
                      var s = stops[n] || []
                      return { value: n, label: n, swatch: s.length ? "#" + s[Math.floor(s.length / 2)] : "" }
                    })
                  }
                  value: String(root.draft.colorPalette || "sunset")
                  onPicked: function(v) { root.setDraft("colorPalette", v) }
                }

                ChoiceChips {
                  width: parent.width
                  visible: root.draft.colorMode !== "rainbow" && root.draft.colorMode !== "palette"
                  label: root.draft.colorMode === "gradient" ? "Gradient from"
                    : (root.draft.colorMode === "stripes" || root.draft.colorMode === "split" ? "First colour" : "Colour")
                  options: {
                    var pal = root.status && root.status.palette ? root.status.palette : ({})
                    var names = root.colorNames.indexOf(String(root.draft.color)) === -1
                      ? [String(root.draft.color)].concat(root.colorNames) : root.colorNames
                    return names.map(function(n) {
                      var hex = /^#?[0-9a-fA-F]{6}$/.test(n) ? n.replace("#", "") : pal[n]
                      return { value: n, label: n.replace(/_/g, " "), swatch: hex ? "#" + hex : "" }
                    })
                  }
                  value: String(root.draft.color || "accent")
                  onPicked: function(v) { root.setDraft("color", v) }
                }

                ChoiceChips {
                  width: parent.width
                  visible: ["gradient", "stripes", "split"].indexOf(root.draft.colorMode) >= 0
                  label: root.draft.colorMode === "gradient" ? "Gradient to" : "Second colour"
                  options: {
                    var pal = root.status && root.status.palette ? root.status.palette : ({})
                    var names = root.colorNames.indexOf(String(root.draft.color2)) === -1
                      ? [String(root.draft.color2)].concat(root.colorNames) : root.colorNames
                    return names.map(function(n) {
                      var hex = /^#?[0-9a-fA-F]{6}$/.test(n) ? n.replace("#", "") : pal[n]
                      return { value: n, label: n.replace(/_/g, " "), swatch: hex ? "#" + hex : "" }
                    })
                  }
                  value: String(root.draft.color2 || "blue")
                  onPicked: function(v) { root.setDraft("color2", v) }
                }

                ChoiceChips {
                  width: parent.width
                  visible: ["gradient", "rainbow", "palette"].indexOf(root.draft.colorMode) >= 0
                  label: "Direction"
                  options: root.status ? root.status.gradients : []
                  value: String(root.draft.gradient || "horizontal")
                  onPicked: function(v) { root.setDraft("gradient", v) }
                }

                LabeledToggle {
                  visible: root.draftIsTdf
                  label: "Keep the TheDraw font's own colours"
                  checked: root.draft.fontColors !== false
                  onToggled: root.setDraft("fontColors", root.draft.fontColors === false)
                }

                ChoiceChips {
                  width: parent.width
                  label: "Fill the letters with"
                  options: root.fillOptions
                  value: String(root.draft.fill || "")
                  onPicked: function(v) { root.setDraft("fill", v) }
                }

                TextField {
                  width: Math.min(parent.width, Style.space(320))
                  placeholderText: "…or type your own fill characters"
                  text: root.fillOptions.some(function(o) { return o.value === String(root.draft.fill || "") }) ? "" : String(root.draft.fill || "")
                  foreground: root.foreground
                  onTextEdited: root.setDraft("fill", text)
                }

                ChoiceChips {
                  width: parent.width
                  label: "Shadow"
                  options: root.status ? root.status.shadows : []
                  value: String(root.draft.shadow || "none")
                  onPicked: function(v) { root.setDraft("shadow", v) }
                }

                ChoiceChips {
                  width: parent.width
                  label: "Border"
                  options: root.status ? root.status.borders : []
                  value: String(root.draft.border || "none")
                  onPicked: function(v) { root.setDraft("border", v) }
                }

                NumberField {
                  visible: !!root.draft.border && root.draft.border !== "none"
                  label: "Space inside the border"
                  from: 0
                  to: 20
                  value: Number(root.draft.padding) || 0
                  foreground: root.foreground
                  onModified: function(v) { root.setDraft("padding", v) }
                }

                ChoiceChips {
                  width: parent.width
                  label: "Mirror"
                  options: root.status ? root.status.flips : []
                  value: String(root.draft.flip || "none")
                  onPicked: function(v) { root.setDraft("flip", v) }
                }
              }

              // ----- Boot: animation
              Column {
                id: bootTab
                width: parent.width
                spacing: Style.space(14)
                visible: root.settingsTab === "boot"

                ChoiceChips {
                  width: parent.width
                  label: "On boot, the art is"
                  options: [{ value: "animated", label: "Animated by an intro effect" }, { value: "static", label: "Shown still" }]
                  value: String(root.draft.style || "animated")
                  onPicked: function(v) { root.setDraft("style", v) }
                }

                // One list per group (core, screensaver, omascii's own, ...);
                // each edits only its own effects and keeps the rest.
                Repeater {
                  model: root.draft.style === "animated" && root.status ? root.status.effectGroups || [] : []
                  delegate: CheckChips {
                    required property var modelData
                    width: bootTab.width
                    label: modelData.name
                    options: modelData.effects
                    values: (root.draft.effects || []).filter(function(e) { return modelData.effects.indexOf(e) >= 0 })
                    playable: true
                    playing: root.animPlaying || root.animLoading ? root.animEffect : ""
                    onChanged: function(v) {
                      var group = modelData.effects
                      var keep = (root.draft.effects || []).filter(function(e) { return group.indexOf(e) < 0 || v.indexOf(e) >= 0 })
                      for (var i = 0; i < v.length; i++) if (keep.indexOf(v[i]) < 0) keep.push(v[i])
                      var all = root.status.effects
                      keep.sort(function(a, b) { return all.indexOf(a) - all.indexOf(b) })
                      root.setDraft("effects", keep)
                    }
                    onPlay: function(v) {
                      if ((root.animPlaying || root.animLoading) && root.animEffect === v) root.stopAnimation()
                      else root.playAnimation(v)
                    }
                  }
                }

                Hint {
                  width: parent.width
                  visible: root.draft.style === "animated"
                  color: root.needsEffect ? Commons.Color.urgent : Commons.Color.menu.text
                  opacity: root.needsEffect ? 1 : 0.55
                  text: root.needsEffect
                    ? "⚠ Tick at least one effect, or choose “Shown still”."
                    : "One ticked effect is picked at random each boot. Each one adds to the initramfs, so fewer boot faster. "
                      + "Press ▶ on any effect to watch it in the preview."
                }

                NumberField {
                  visible: root.draft.style === "animated"
                  label: "Longest intro (frames, 50 per second)"
                  from: 10
                  to: 600
                  stepSize: 10
                  value: Number(root.draft.maxFrames) || 200
                  foreground: root.foreground
                  onModified: function(v) { root.setDraft("maxFrames", v) }
                }
              }
            }
          }
        }

        // ---------- Footer: ③ status + actions ----------
        Item {
          id: footer
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Math.max(actions.height, nameRow.visible ? nameRow.implicitHeight : 0)

          Text {
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.rightMargin: root.gap
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.naming
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.message !== "" ? root.message
              : (root.status
                 ? "On boot now: " + (root.status.plymouthTheme === "omascii" && root.status.applied
                      ? (root.status.applied.source === "image"
                         ? String(root.status.applied.image).replace(/^.*\//, "") : root.status.applied.font)
                      : (root.status.plymouthTheme || "?") + " theme")
                   + (root.notOnBoot ? "  ·  your design isn't on the boot screen yet" : "  ·  ✓ your design is on the boot screen")
                   + "    Ctrl+P play · Ctrl+S save · Ctrl+Enter apply · Esc close"
                 : "")
            color: root.messageIsError ? Commons.Color.urgent : root.foreground
            opacity: root.messageIsError ? 1 : 0.65
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
          }

          // Naming a library entry
          Row {
            id: nameRow
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.rightMargin: root.gap
            anchors.verticalCenter: parent.verticalCenter
            visible: root.naming
            spacing: Style.space(8)

            Caption {
              anchors.verticalCenter: parent.verticalCenter
              text: "Name this boot screen"
            }
            TextField {
              id: nameField
              width: Math.max(Style.space(160), parent.width - x - nameSave.width - nameCancel.width - parent.spacing * 2)
              placeholderText: "e.g. Green graffiti"
              foreground: root.foreground
              onAccepted: root.saveToLibrary(text)
            }
            Button {
              id: nameSave
              anchors.verticalCenter: parent.verticalCenter
              text: "Save"
              bordered: true
              active: true
              foreground: root.foreground
              onClicked: root.saveToLibrary(nameField.text)
            }
            Button {
              id: nameCancel
              anchors.verticalCenter: parent.verticalCenter
              text: "Cancel"
              bordered: true
              foreground: root.foreground
              onClicked: root.naming = false
            }
          }

          Row {
            id: actions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Button {
              text: "Undo boot change"
              tooltipText: "Switch back to the boot theme used before omascii"
              bordered: true
              foreground: root.foreground
              visible: !!root.status && root.status.plymouthTheme === "omascii"
              onClicked: root.restore()
            }
            Button {
              text: "Export GIF"
              tooltipText: "Build the real boot frames and open a GIF of the first intro"
              bordered: true
              foreground: root.foreground
              onClicked: root.exportGif()
            }
            Button {
              text: "★ Save to library"
              tooltipText: "Keep this design under a name in My boot screens (Ctrl+S)"
              bordered: true
              foreground: root.foreground
              visible: !root.naming
              onClicked: root.startNaming()
            }
            Button {
              text: "③ Apply to boot"
              tooltipText: "Build, install with sudo and rebuild the initramfs (Ctrl+Enter)"
              bordered: true
              active: true
              foreground: root.foreground
              onClicked: root.applyToBoot()
            }
          }
        }
      }
    }
  }
}

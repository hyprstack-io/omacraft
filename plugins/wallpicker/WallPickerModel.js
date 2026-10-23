// What the picker shows, whatever tab it comes from: one entry per
// wallpaper, { key, target, preview, full, label, detail, meta }.
//   key      the favourite key (hyprskin's rule: a Wallhaven id, else the path)
//   target   what `hyprskin apply` and `hyprskin favorite` are handed
//   preview  a local file (or a URL) drawn on the card
//   full     a sharper picture for the expanded card, loaded once it settles
//   meta     a Wallhaven result, kept with a favourite so it keeps its preview

function basename(path) {
  var s = String(path || "")
  return s.substring(s.lastIndexOf("/") + 1)
}

function nameForPath(path) {
  return basename(path).replace(/\.[^/.]+$/, "")
}

function labelForPath(path) {
  return nameForPath(path).replace(/[-_]+/g, " ").replace(/\b\w/g, function(match) { return match.toUpperCase() })
}

// The same key hyprskin and OmaCraft use, so one heart covers a search
// result, its downloaded file and its favourite.
function favoriteKey(target) {
  var s = String(target || "")
  var m = basename(s).match(/^wallhaven-([a-z0-9]+)\.\w+$/)
  if (m) return m[1]
  m = s.match(/wallhaven\.cc\/w\/([a-z0-9]+)/)
  if (m) return m[1]
  return s
}

// `omarchy-menu-images --print-rows`: "image<TAB>thumbnail" per line.
function parseRows(text) {
  var thumbs = {}
  var order = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var columns = lines[i].split("\t")
    if (!columns[0]) continue
    if (!(columns[0] in thumbs)) order.push(columns[0])
    thumbs[columns[0]] = columns[1] || columns[0]
  }
  return { order: order, thumbs: thumbs }
}

function themeEntries(rowsText) {
  var rows = parseRows(rowsText)
  var seen = {}
  var out = []
  for (var i = 0; i < rows.order.length; i++) {
    var path = rows.order[i]
    var name = basename(path)
    if (seen[name]) continue
    seen[name] = true
    out.push({ key: favoriteKey(path), target: path, preview: rows.thumbs[path], full: "",
               label: labelForPath(path), detail: "", meta: null })
  }
  return out
}

function resolution(entry) {
  return entry && entry.resolution ? entry.resolution : ""
}

function searchEntries(results) {
  var out = []
  for (var i = 0; i < (results || []).length; i++) {
    var r = results[i]
    var detail = [resolution(r), r.favorites ? "♥ " + r.favorites : "", r.category || ""].filter(Boolean).join("  ·  ")
    out.push({ key: r.id, target: r.id, preview: r.thumb || r.thumbRemote || "", full: r.full || "",
               label: r.id, detail: detail, meta: r })
  }
  return out
}

// thumbs: path -> Omarchy's cached thumbnail, when it has made one.
function libraryEntries(library, thumbs) {
  var out = []
  for (var i = 0; i < (library || []).length; i++) {
    var path = library[i].path
    if (!path) continue
    out.push({ key: favoriteKey(path), target: path, preview: (thumbs && thumbs[path]) || path, full: "",
               label: labelForPath(path), detail: "", meta: null })
  }
  return out
}

function favoriteEntries(favorites, thumbs) {
  var out = []
  for (var i = 0; i < (favorites || []).length; i++) {
    var f = favorites[i]
    if (f.missing) continue
    var target = f.target || f.path || f.id || f.key
    var local = String(target).charAt(0) === "/"
    var preview = (local && thumbs && thumbs[target]) || (local ? target : (f.thumb || f.thumbRemote || ""))
    var meta = f.local ? null : { full: f.full || "", thumbRemote: f.thumbRemote || "", url: f.url || "",
                                  resolution: f.resolution || "", colors: f.colors || [], thumb: f.thumb || "" }
    out.push({ key: f.key || favoriteKey(target), target: target, preview: preview,
               full: local ? "" : (f.full || ""),
               label: f.id ? f.id : labelForPath(target), detail: resolution(f), meta: meta })
  }
  return out
}

function matches(entry, filterText) {
  var needle = String(filterText || "").toLowerCase()
  if (!needle) return true
  return String(entry.label || "").toLowerCase().indexOf(needle) !== -1
      || nameForPath(entry.target).toLowerCase().indexOf(needle) !== -1
}

function matchingIndices(entries, filterText) {
  var indices = []
  for (var i = 0; i < entries.length; i++)
    if (matches(entries[i], filterText)) indices.push(i)
  return indices
}

// Where the current wallpaper sits in a list, or 0.
function indexOfCurrent(entries, current) {
  if (!current) return 0
  var name = basename(current)
  var key = favoriteKey(current)
  for (var i = 0; i < entries.length; i++) {
    var t = entries[i].target
    if (t === current || basename(t) === name || entries[i].key === key) return i
  }
  return 0
}

// The image picker's windowing: only the slices that fit are rendered, and
// delegates that stay in view are kept as the selection moves.
function visibleWindow(indices, selectedIndex, radius) {
  var position = indices.indexOf(selectedIndex)
  if (position < 0) position = 0
  var items = []
  for (var i = Math.max(0, position - radius); i < Math.min(indices.length, position + radius + 1); i++)
    items.push({ entryIndex: indices[i], relativeIndex: i - position })
  return items
}

function syncWindow(model, items) {
  var wanted = {}
  for (var i = 0; i < items.length; i++) wanted[items[i].entryIndex] = true
  for (var i = model.count - 1; i >= 0; i--) {
    if (!wanted[model.get(i).entryIndex]) model.remove(i)
  }
  for (var i = 0; i < items.length; i++) {
    var existing = i
    while (existing < model.count && model.get(existing).entryIndex !== items[i].entryIndex) existing++
    if (existing === model.count) {
      model.insert(i, items[i])
    } else {
      if (existing !== i) model.move(existing, i, 1)
      model.setProperty(i, "relativeIndex", items[i].relativeIndex)
    }
  }
}

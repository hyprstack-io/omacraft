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

// ------------------------------------------------------------ tab colours
//
// The tabs stand out against the wallpaper behind them: their colour is the
// wallpaper accent's opposite hue, light on a dark wallpaper and dark on a
// light one, and their words are black or white, whichever reads better on
// it (always past WCAG's 4.5:1 for text).

function parseHex(hex) {
  var m = String(hex || "").trim().match(/^#?([0-9a-f]{6})$/i)
  if (!m) return null
  var n = parseInt(m[1], 16)
  return { r: (n >> 16 & 255) / 255, g: (n >> 8 & 255) / 255, b: (n & 255) / 255 }
}

function toHex(c) {
  function part(v) {
    var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
    return s.length < 2 ? "0" + s : s
  }
  return "#" + part(c.r) + part(c.g) + part(c.b)
}

function rgbToHsl(c) {
  var max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b)
  var l = (max + min) / 2, h = 0, s = 0
  if (max !== min) {
    var d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0)
    else if (max === c.g) h = (c.b - c.r) / d + 2
    else h = (c.r - c.g) / d + 4
    h /= 6
  }
  return { h: h, s: s, l: l }
}

function hslToRgb(h, s, l) {
  function hue(p, q, t) {
    if (t < 0) t += 1
    if (t > 1) t -= 1
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
  }
  if (s === 0) return { r: l, g: l, b: l }
  var q = l < 0.5 ? l * (1 + s) : l + s - l * s
  var p = 2 * l - q
  return { r: hue(p, q, h + 1 / 3), g: hue(p, q, h), b: hue(p, q, h - 1 / 3) }
}

function luminance(c) {
  function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}

function contrast(a, b) {
  var la = luminance(a), lb = luminance(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// palette: hyprskin's, with background and accent as "#rrggbb".
// Returns { fill, text } as "#rrggbb".
function tabColors(palette) {
  var p = palette || {}
  var wall = parseHex(p.background) || parseHex(p.dark_background) || { r: 0.07, g: 0.08, b: 0.09 }
  var accent = parseHex(p.accent) || wall
  var a = rgbToHsl(accent)
  var dark = luminance(wall) < 0.18
  var fill = hslToRgb((a.h + 0.5) % 1, Math.max(0.45, Math.min(0.75, a.s)), dark ? 0.74 : 0.26)
  var black = { r: 0.04, g: 0.04, b: 0.05 }
  var white = { r: 1, g: 1, b: 1 }
  var text = contrast(fill, black) >= contrast(fill, white) ? black : white
  // A fill too near the middle for either: push it away until it reads.
  for (var i = 0; contrast(fill, text) < 4.5 && i < 20; i++) {
    var f = rgbToHsl(fill)
    fill = hslToRgb(f.h, f.s, text === black ? Math.min(1, f.l + 0.03) : Math.max(0, f.l - 0.03))
  }
  return { fill: toHex(fill), text: toHex(text) }
}

// `hyprctl getoption general:col.active_border -j`: {"gradient": "ee4b9aaf
// ee82948d 45deg"} (AARRGGBB) or {"int": ...}. The first two colours as
// "#rrggbb", the first twice when there's one; [] when there are none.
function borderColors(jsonText) {
  var data = {}
  try { data = JSON.parse(String(jsonText || "")) || {} } catch (e) { return [] }
  var source = String(data.gradient || data.str || "")
  var colors = []
  var tokens = source.split(/\s+/)
  for (var i = 0; i < tokens.length && colors.length < 2; i++) {
    var t = tokens[i].replace(/^0x/i, "")
    var m = t.match(/^rgba?\(([0-9a-f]{6})([0-9a-f]{2})?\)$/i)
    if (m) colors.push("#" + m[1])
    else if (/^[0-9a-f]{8}$/i.test(t)) colors.push("#" + t.substring(2))
  }
  if (colors.length === 1) colors.push(colors[0])
  return colors
}

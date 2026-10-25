import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "BarModel.js" as BarModel

Item {
  id: root

  // >>> modarchy: hidden bar icons
  // Modules listed in ~/.config/modarchy/bar-hidden.json stay loaded (their
  // plugins keep running) but take no room and draw nothing. Added by
  // Modarchy; it removes this block itself, or delete it by hand.
  property var modarchyHiddenIds: []
  FileView {
    path: Quickshell.env("HOME") + "/.config/modarchy/bar-hidden.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.modarchyHiddenIds = JSON.parse(text()).hidden || [] }
      catch (e) { root.modarchyHiddenIds = [] }
    }
    onLoadFailed: root.modarchyHiddenIds = []
  }
  // <<< modarchy
  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  // Injected by the host shell so bar slots can resolve enabled widgets.
  property var barWidgetRegistry: fallbackBarWidgetRegistry
  // Read-only registry view for third-party full bars; the built-in bar does
  // not otherwise need it, but declaring it keeps clone construction atomic.
  property var pluginRegistry: null
  // Injected by the host shell every time shell.json is reloaded. Holds the
  // `bar:` subtree: position, centerAnchor, layout. The host owns file IO;
  // the bar just renders whatever it's handed. The bar font follows the
  // OS-level fontconfig monospace binding — it is not stored in shell.json.
  property var barConfig: ({})
  // Injected by the host shell. Used for shell-wide actions such as opening
  // settings and persisting inline widget state.
  property var shell: null
  // Manifest for the active bar option. Present for custom bars and useful for
  // diagnostics; the built-in bar does not otherwise need it.
  property var manifest: null
  QtObject {
    id: fallbackBarWidgetRegistry
    property var widgets: ({})
    property int revision: 0
    function metadataFor(id) { return null }
  }
  // Mirrors the on-disk `bar-off` flag so the user can hide the bar without
  // killing the entire shell. Hidden panels stay mapped but park off-screen
  // without an exclusion zone; updated by the FileView watcher further down.
  property bool barHidden: false
  property string home: Quickshell.env("HOME")
  property string stateHome: home + "/.local/state"
  property string omarchyConfigDir: home + "/.config/omarchy"
  property var fallbackBarConfig: ({
    position: "top",
    transparent: false,
    centerAnchor: "omarchy.clock",
    layout: { left: [], center: [], right: [] }
  })
  property var layoutConfig: fallbackBarConfig.layout
  property string centerAnchor: ""
  property bool requestedTransparent: false
  property bool useTransparentForeground: false
  property bool transparent: false
  property bool centerSectionHovered: false
  // One bar surface exists per monitor and each reports into this count, so a
  // pointer crossing from one monitor's bar to another's stays counted however
  // the enter and leave interleave. A single shared bool would be left false by
  // whichever event landed last.
  property int barHoverCount: 0
  // True while the pointer is over any bar, widgets included.
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property int barConfigSerial: 0
  property string position: "top"
  // Resolves through fontconfig at paint time (Style.font.family defaults
  // to "monospace"), so changing the system font (via `omarchy-font-set`)
  // updates the bar without a reload.
  property string fontFamily: {
    var f = styleConfig.fontFamily
    return typeof f === "string" && f.trim() !== "" ? f.trim() : Style.font.family
  }
  // Bound to the central Color singleton so the bar tracks shell.toml's
  // [bar] section. Property names kept for the rest of this file's bindings.
  property color themeForeground: styleColor("fg", Commons.Color.bar.text)
  property color themeContrastForeground: Commons.Color.background
  property color transparentForeground: Commons.Color.bar.text
  // Underlined segments leave the text on the bar itself, so it keeps the
  // bar's own text colour rather than the dark ink of a filled segment.
  readonly property bool segFilled: segActive && segSolid && segKind !== "underline"
  property color foreground: segFilled ? segText : themeForeground
  property color barForeground: segFilled ? segText : (useTransparentForeground ? transparentForeground : themeForeground)
  property bool foregroundAnimationEnabled: true
  // Behind segments the bar background carries no text, so only a bar
  // without segments holds it to the contrast minimum.
  property color background: segActive ? styleColor("bg", Commons.Color.bar.background)
    : readableFill(styleColor("bg", Commons.Color.bar.background), themeForeground, segMinContrast)
  property color urgent: Commons.Color.bar.active

  // ------------------------------------------------------------------
  // Segment styling ("bar styles")
  //
  // Everything below is driven by the optional `style` object inside the
  // `bar` subtree of shell.json, written by `omarchy-bar-style`. With no
  // `style` (or shape "none") this bar renders exactly like omarchy.bar.
  //
  //   shape    arrow | slant | backslant | trapezoid | hex | round | block |
  //            leaf | tab | underline | none
  //   solid    true: fully coloured segments with dark text
  //            false: segments are a tint of the colour over the bar background
  //   tint     strength of that tint (0..1) when solid is false
  //   colors   cycle (rotate through the palette) | mono (accent only)
  //   palette  colour names taken from the active theme's colors.toml
  //   gap      pixels between segments        inset  vertical inset of segments
  //   depth    arrow point depth as a fraction of segment height
  //   edge     pixels between the bar ends and the first/last segment
  //   flatEnds true: the outermost segments have a flat outer edge
  //   float    pixels of clear space around the bar (floating bar)
  //   size     bar thickness in px (16-96)   radius  block corner radius
  //   fontFamily  font for the bar's widgets
  //   minContrast  lowest WCAG contrast allowed between the text and any
  //            segment (or the bar background); fills that fall short are
  //            darkened or lightened until they reach it. 0 turns it off.
  //   outline  hairline width (px) around each segment, or around the whole
  //            bar when it has no segments    outlineColor  its colour
  //   shadow   0..1 drop shadow under segments (or the floating bar)
  //   backdrop 0..1 opacity of a bar-wide background drawn behind the
  //            segments even when the bar is transparent or floating
  //   barOpacity      0..1 opacity of the docked bar background
  //   segmentOpacity  0.1..1 opacity of the segment fills
  //   hoverColor      #hex a hovered module blends toward (segments) or is
  //                   highlighted with (no segments)
  //   hoverOpacity    0..1 how strongly the hover colour shows
  //   iconFont        font for custom module icons (default: fontFamily)
  //
  // Per-module settings on a layout entry (beside id), all optional:
  //   icon       glyph replacing the widget's own   iconFont  its font
  //   font       font for the widget's text         color     its text/icon colour
  //   hoverColor its own hover colour               opacity   0.1..1 of the whole widget
  // ------------------------------------------------------------------
  readonly property var styleConfig: Util.isPlainObject(barConfig) && Util.isPlainObject(barConfig.style) ? barConfig.style : ({})

  function styleValue(key, fallback) {
    var v = styleConfig[key]
    return v === undefined || v === null ? fallback : v
  }

  // Per-part colour overrides written by the omabar16 customizer. Each is an
  // optional "#rrggbb" string; when absent the theme's own colour is used.
  //   bg       bar background            fg      text/icons
  //   accent   open-panel indicator      regions {left,center,right} segment colour per section
  //   modules  {widget-id: colour} segment colour of one widget
  function validHex(v) {
    return typeof v === "string" && /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(v)
  }

  function styleColor(key, fallback) {
    var v = styleConfig[key]
    return validHex(v) ? Qt.color(v) : fallback
  }

  readonly property color segText: styleColor("fg", Commons.Color.background)
  readonly property color segAccent: styleColor("accent", Commons.Color.accent)

  readonly property string segShape: String(styleValue("shape", "none"))
  readonly property string segKind: segShape === "none" ? "none" : (vertical ? "block" : segShape)
  readonly property bool segActive: segKind !== "none"
  readonly property bool segSolid: styleValue("solid", true) === true
  readonly property string segColors: String(styleValue("colors", "cycle"))
  readonly property real segTint: Math.max(0, Math.min(1, Number(styleValue("tint", 0.3))))
  readonly property int segGap: Math.round(Number(styleValue("gap", 1)))
  readonly property int segInset: Math.round(Number(styleValue("inset", 0)))
  readonly property real segDepth: Number(styleValue("depth", 0.42))
  readonly property int segPad: Math.round(Number(styleValue("pad", 3)))
  readonly property int segEdge: segActive ? Math.round(Number(styleValue("edge", 0))) : Style.space(8)
  readonly property real segRadius: styleConfig.radius === undefined ? Style.cornerRadius : Math.max(0, Number(styleConfig.radius))
  readonly property bool segFlatEnds: styleValue("flatEnds", true) === true
  readonly property int segFloat: segActive ? Math.max(0, Math.round(Number(styleValue("float", 0)))) : 0
  readonly property real segMinContrast: Math.max(0, Math.min(21, Number(styleValue("minContrast", 4.5)) || 0))
  readonly property int segOutline: Math.max(0, Math.min(6, Math.round(Number(styleValue("outline", 0)) || 0)))
  readonly property color segOutlineColor: styleColor("outlineColor", Qt.darker(Commons.Color.background, 1.6))
  readonly property real segShadow: Math.max(0, Math.min(1, Number(styleValue("shadow", 0)) || 0))
  readonly property real barBackdrop: Math.max(0, Math.min(1, Number(styleValue("backdrop", 0)) || 0))
  readonly property int segShadowOffset: Math.max(1, Math.round(barSize * 0.08))
  readonly property real barOpacity: Math.max(0, Math.min(1, Number(styleValue("barOpacity", 1))))
  readonly property real segOpacity: Math.max(0.1, Math.min(1, Number(styleValue("segmentOpacity", 1)) || 1))
  readonly property bool hoverStyled: validHex(styleConfig.hoverColor) || styleConfig.hoverOpacity !== undefined
  readonly property color hoverColor: styleColor("hoverColor", barForeground)
  readonly property real hoverOpacity: Math.max(0, Math.min(1, Number(styleValue("hoverOpacity", segActive ? 0.35 : 0.14))))
  readonly property string iconFontFamily: {
    var f = styleConfig.iconFont
    return typeof f === "string" && f.trim() !== "" ? f.trim() : fontFamily
  }

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, c.a * a) }

  // WCAG relative luminance and contrast ratio.
  function relativeLuminance(c) {
    function channel(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
  }

  function contrastRatio(a, b) {
    var la = relativeLuminance(a), lb = relativeLuminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
  }

  // `fill` pushed toward black (light ink) or white (dark ink) just far
  // enough for `ink` to reach `minimum` contrast on it.
  function readableFill(fill, ink, minimum) {
    if (minimum <= 1 || contrastRatio(fill, ink) >= minimum) return fill
    var target = relativeLuminance(ink) > relativeLuminance(fill) ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)
    var c = fill
    for (var t = 0.06; t <= 1.0001 && contrastRatio(c, ink) < minimum; t += 0.06)
      c = mixColors(fill, target, Math.min(1, t))
    return Qt.rgba(c.r, c.g, c.b, fill.a)
  }
  readonly property var segPaletteNames: {
    var names = styleValue("palette", null)
    return (names !== null && typeof names === "object" && names.length > 0) ? names : ["accent", "blue", "magenta", "green", "yellow", "cyan"]
  }

  // The active theme's colors.toml, re-read whenever the theme changes. Themes
  // name their hues either `blue`/`green`/... or ANSI `color4`/`color2`/...;
  // themeHue() resolves both.
  property var themeColors: ({})

  function parseThemeColors(text) {
    var out = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["'](#[0-9A-Fa-f]{6})["']/)
      if (m) out[m[1]] = m[2]
    }
    return out
  }

  function themeHue(name) {
    var t = themeColors
    var n = String(name)
    var alias = {
      accent: ["accent"],
      red: ["red", "color1"],
      green: ["green", "color2"],
      yellow: ["yellow", "color3"],
      blue: ["blue", "color4", "color12"],
      magenta: ["magenta", "color5", "color13"],
      cyan: ["cyan", "color6", "color14"],
      orange: ["orange", "color9"],
      foreground: ["foreground"]
    }
    var keys = alias[n] || [n]
    for (var i = 0; i < keys.length; i++) if (t[keys[i]]) return t[keys[i]]
    if (/^#[0-9A-Fa-f]{6}$/.test(n)) return n
    return null
  }

  function colorDistance(a, b) {
    return Math.sqrt(Math.pow(a.r - b.r, 2) + Math.pow(a.g - b.g, 2) + Math.pow(a.b - b.b, 2))
  }

  function mixColors(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }

  // Palette rotation: the requested hues, minus any the theme lacks, any that
  // vanish into the bar background and near-duplicates. Monochrome themes get
  // a tonal ramp of their accent so neighbouring segments still separate.
  function buildPalette() {
    var out = []
    var bg = Commons.Color.background
    for (var i = 0; i < segPaletteNames.length; i++) {
      var literal = validHex(String(segPaletteNames[i]))
      var hex = themeHue(segPaletteNames[i])
      if (!hex) continue
      var c = Qt.color(hex)
      if (literal) { out.push(c); continue }
      if (colorDistance(c, bg) < 0.14) continue
      var dup = false
      for (var j = 0; j < out.length; j++) if (colorDistance(c, out[j]) < 0.09) dup = true
      if (!dup) out.push(c)
    }
    if (out.length === 0) out.push(Qt.color(Commons.Color.accent))
    var base = out[0]
    var ramp = [Qt.darker(base, 1.4), Qt.lighter(base, 1.3), Qt.darker(base, 1.8)]
    for (var k = 0; out.length < 3; k++) out.push(ramp[k % ramp.length])
    return out
  }

  readonly property var segPalette: buildPalette()

  function segmentColor(region, idx, count, name) {
    var mods = styleConfig.modules
    if (mods && typeof mods === "object" && validHex(mods[name])) return Qt.color(mods[name])
    var regs = styleConfig.regions
    if (regs && typeof regs === "object" && validHex(regs[region])) return Qt.color(regs[region])
    var p = segPalette
    var i = idx < 0 ? 0 : idx
    if (segColors === "mono") return i % 2 === 0 ? p[0] : mixColors(p[0], Commons.Color.background, 0.28)
    // Outer ends of the bar take the accent; hues rotate inward from there.
    var k = region === "right" ? (count - 1 - i) : (region === "center" ? i + 1 : i)
    return p[((k % p.length) + p.length) % p.length]
  }

  function segmentFill(base, lit) {
    var fill = segSolid ? (lit ? Qt.lighter(base, 1.14) : base)
      : mixColors(background, base, Math.min(1, segTint + (lit ? 0.16 : 0)))
    return readableFill(fill, foreground, segMinContrast)
  }

  FileView {
    id: themeColorsFile
    path: root.stateHome + "/omarchy/current/theme/colors.toml"
    watchChanges: false
    printErrors: false
    onLoaded: root.themeColors = root.parseThemeColors(text())
  }

  // theme.name is rewritten on every theme switch; give the theme files a
  // moment to land, then re-read the palette.
  FileView {
    path: root.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: themeColorsReload.restart()
  }

  Timer {
    id: themeColorsReload
    interval: 400
    onTriggered: themeColorsFile.reload()
  }

  Behavior on barForeground { enabled: root.foregroundAnimationEnabled; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on urgent { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0
  property var activePopout: null
  property var barDragSource: null
  property var barDragTarget: null
  property var barDragTargetGeometry: null
  property bool barDragAfter: false
  property var barDragWindow: null
  property var barDragScreen: null
  property url barDragImageUrl: ""
  property real barDragSceneX: 0
  property real barDragSceneY: 0
  property real barDragScreenX: 0
  property real barDragScreenY: 0
  property real barDragOffsetX: 0
  property real barDragOffsetY: 0
  property bool barMoveActive: false
  property string barMoveCandidate: ""
  property var barMoveWindow: null
  property var barMoveScreen: null
  property var clickTargets: []
  property var moduleSlots: []
  property var pluginBarApis: ({})
  property var pluginObjectOwners: []

  Component {
    id: pluginBarApiComponent
    PluginBarApi { }
  }

  function publicLayoutConfig() {
    return JSON.parse(JSON.stringify(root.layoutConfig || {}))
  }

  function bindPluginBarApi(api) {
    if (!api) return
    api.foreground = Qt.binding(function() { return root.foreground })
    api.barForeground = Qt.binding(function() { return root.barForeground })
    api.background = Qt.binding(function() { return root.background })
    api.urgent = Qt.binding(function() { return root.urgent })
    api.fontFamily = Qt.binding(function() { return root.fontFamily })
    api.position = Qt.binding(function() { return root.position })
    api.vertical = Qt.binding(function() { return root.vertical })
    api.barSize = Qt.binding(function() { return root.barSize })
    api.transparent = Qt.binding(function() { return root.transparent })
    api.foregroundAnimationEnabled = Qt.binding(function() { return root.foregroundAnimationEnabled })
    api.centerSectionRevealHeld = Qt.binding(function() { return root.centerSectionRevealHeld })
    api._centerHoverRevealSuppressed = Qt.binding(function() { return root.centerHoverRevealSuppressed })
    root.syncPluginBarApiObjects(api)
  }

  function syncPluginBarApiObjects(api) {
    if (!api) return
    api.activePopout = root.pluginOwnsBarObject(api.pluginId, root.activePopout)
      ? root.activePopout : (root.activePopout ? api.foreignPopoutMarker : null)
    api.clickTargets = root.pluginClickTargets(api.pluginId)
    api.layoutConfig = root.publicLayoutConfig()
  }

  function pluginObjectRecord(target) {
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var record = pluginObjectOwners[i]
      if (record && record.target === target) return record
    }
    return null
  }

  function markPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    if (!key || !target) return false
    var record = root.pluginObjectRecord(target)
    if (record && record.pluginId !== key) return false
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var existing = pluginObjectOwners[i]
      if (!existing || existing.target !== target) next.push(existing)
    }
    var updated = record || { target: target, pluginId: key, clickTarget: false, popout: false }
    updated[role] = true
    next.push(updated)
    pluginObjectOwners = next
    return true
  }

  function unmarkPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var record = pluginObjectOwners[i]
      if (!record || record.target !== target || record.pluginId !== key) {
        next.push(record)
        continue
      }
      record[role] = false
      if (record.clickTarget || record.popout) next.push(record)
    }
    pluginObjectOwners = next
  }

  function pluginOwnsBarObject(pluginId, target) {
    var record = target ? root.pluginObjectRecord(target) : null
    return !!record && record.pluginId === String(pluginId || "")
  }

  function pluginClickTargets(pluginId) {
    var out = []
    for (var i = 0; i < root.clickTargets.length; i++) {
      var target = root.clickTargets[i]
      if (root.pluginOwnsBarObject(pluginId, target)) out.push(target)
    }
    return out
  }

  function syncAllPluginBarApiObjects() {
    for (var id in pluginBarApis) root.syncPluginBarApiObjects(pluginBarApis[id])
  }

  function registerPluginClickTarget(pluginId, target) {
    if (!root.markPluginObject(pluginId, target, "clickTarget")) return
    root.registerClickTarget(target)
  }

  function unregisterPluginClickTarget(pluginId, target) {
    if (!root.pluginOwnsBarObject(pluginId, target)) return
    root.unregisterClickTarget(target)
    root.unmarkPluginObject(pluginId, target, "clickTarget")
  }

  function requestPluginPopout(pluginId, owner) {
    if (!root.markPluginObject(pluginId, owner, "popout")) return
    root.requestPopout(owner)
  }

  function releasePluginPopout(pluginId, owner) {
    if (!root.pluginOwnsBarObject(pluginId, owner)) return
    root.releasePopout(owner)
    root.unmarkPluginObject(pluginId, owner, "popout")
  }

  function pluginBarApiFor(pluginId, moduleName, registered) {
    var key = String(pluginId || "")
    if (!key) return null

    var pluginShell = null
    if (registered && root.shell && typeof root.shell.pluginShellForId === "function") {
      // Only the trusted built-in bar receives ShellRoot and can request a
      // service-capable facade for the widget it is instantiating.
      pluginShell = root.shell.pluginShellForId(moduleName)
    } else if (root.shell && typeof root.shell.pluginShellForBarEntry === "function") {
      // Replacement bars receive a service-less entry facade. Giving an
      // untrusted bar a generic facade factory would let it retrieve another
      // third-party plugin's live service object.
      pluginShell = root.shell.pluginShellForBarEntry(key, moduleName)
    }

    if (pluginBarApis[key]) {
      pluginBarApis[key].shell = pluginShell
      return pluginBarApis[key]
    }

    var api = pluginBarApiComponent.createObject(null, {
      pluginId: key,
      moduleName: String(moduleName || ""),
      shell: pluginShell,
      _showTooltip: function(target, text) { root.showTooltip(target, text) },
      _hideTooltip: function(target) { root.hideTooltip(target) },
      _registerClickTarget: function(target) { root.registerPluginClickTarget(key, target) },
      _unregisterClickTarget: function(target) { root.unregisterPluginClickTarget(key, target) },
      _requestPopout: function(owner) { root.requestPluginPopout(key, owner) },
      _releasePopout: function(owner) { root.releasePluginPopout(key, owner) },
      _switchPanelFrom: function(owner, direction) { return root.switchPanelFrom(owner, direction) },
      _targetBelongsToWindow: function(target, window) { return root.targetBelongsToWindow(target, window) },
      _moduleWidgets: function(requestedId) {
        return String(requestedId || "") === String(moduleName || "")
          ? root.moduleWidgets(moduleName) : []
      },
      _run: function(command) { root.run(command) },
      _setCenterHoverRevealSuppressed: function(value) {
        root.centerHoverRevealSuppressed = !!value
      }
    })
    if (!api) return null
    root.bindPluginBarApi(api)

    var next = ({})
    for (var id in pluginBarApis) next[id] = pluginBarApis[id]
    next[key] = api
    pluginBarApis = next
    return api
  }

  function pluginBarApiUsed(pluginId) {
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.pluginApiId === pluginId) return true
    }
    return false
  }

  function releasePluginObjects(pluginId) {
    var owned = pluginObjectOwners.slice()
    for (var i = 0; i < owned.length; i++) {
      var record = owned[i]
      if (!record || record.pluginId !== pluginId) continue
      if (record.clickTarget) root.unregisterClickTarget(record.target)
      if (record.popout && root.activePopout === record.target) root.releasePopout(record.target)
    }
    pluginObjectOwners = pluginObjectOwners.filter(function(record) {
      return record && record.pluginId !== pluginId
    })
  }

  function prunePluginBarApis() {
    var next = ({})
    for (var id in pluginBarApis) {
      var api = pluginBarApis[id]
      if (root.pluginBarApiUsed(id)) {
        next[id] = api
        continue
      }
      root.releasePluginObjects(id)
      if (api && typeof api.destroy === "function") api.destroy()
    }
    pluginBarApis = next
  }

  onActivePopoutChanged: syncAllPluginBarApiObjects()
  onClickTargetsChanged: syncAllPluginBarApiObjects()
  onLayoutConfigChanged: syncAllPluginBarApiObjects()
  onModuleSlotsChanged: Qt.callLater(prunePluginBarApis)

  Component.onDestruction: {
    for (var id in pluginBarApis) {
      root.releasePluginObjects(id)
      if (pluginBarApis[id] && typeof pluginBarApis[id].destroy === "function")
        pluginBarApis[id].destroy()
    }
    pluginBarApis = ({})
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
  }

  function unregisterModuleSlot(slot) {
    var next = moduleSlots.filter(function(item) { return item !== slot })
    moduleSlots = next
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0)
      })
    }
    return out
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function clearBarDrag() {
    barDragSource = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragTarget = null
    barDragTargetGeometry = null
    barDragAfter = false
    barDragSceneX = 0
    barDragSceneY = 0
    barDragScreenX = 0
    barDragScreenY = 0
    barDragOffsetX = 0
    barDragOffsetY = 0
  }

  function windowScreenPoint(scenePoint, window) {
    var x = scenePoint ? scenePoint.x : 0
    var y = scenePoint ? scenePoint.y : 0
    if (!window || !window.screen) return { x: x, y: y }

    if (root.position === "bottom")
      y += Math.max(0, window.screen.height - window.height)
    else if (root.position === "right")
      x += Math.max(0, window.screen.width - window.width)

    return { x: x, y: y }
  }

  function barDragScreenPoint(scenePoint) {
    return windowScreenPoint(scenePoint, barDragWindow)
  }

  function dropMarkerRect(slot, after) {
    if (!slot) return null

    try {
      var slotPoint = slot.mapToItem(null, 0, 0)
      var screenPoint = barDragScreenPoint(slotPoint)
      var thickness = Style.spacing.xs
      if (vertical) {
        return {
          x: screenPoint.x,
          y: screenPoint.y + (after ? slot.height : 0) - thickness / 2,
          width: slot.width,
          height: thickness
        }
      }

      return {
        x: screenPoint.x + (after ? slot.width : 0) - thickness / 2,
        y: screenPoint.y,
        width: thickness,
        height: slot.height
      }
    } catch (e) {
      return null
    }
  }

  // Split the screen along its diagonals (in normalized space, so widescreens
  // don't bias toward left/right): whichever triangle holds the cursor names
  // the candidate edge.
  function nearestScreenEdge(point, screen) {
    var nx = screen.width > 0 ? Util.clamp(point.x / screen.width, 0, 1) : 0.5
    var ny = screen.height > 0 ? Util.clamp(point.y / screen.height, 0, 1) : 0.5

    var edge = "top"
    var best = ny
    if (1 - ny < best) { edge = "bottom"; best = 1 - ny }
    if (nx < best) { edge = "left"; best = nx }
    if (1 - nx < best) { edge = "right"; best = 1 - nx }
    return edge
  }

  function beginBarMove(window) {
    barMoveWindow = window
    barMoveScreen = window ? window.screen : null
    barMoveCandidate = position
    barMoveActive = true
  }

  function updateBarMove(screenPoint) {
    if (!barMoveActive || !barMoveScreen) return
    barMoveCandidate = nearestScreenEdge(screenPoint, barMoveScreen)
  }

  function clearBarMove() {
    barMoveActive = false
    barMoveCandidate = ""
    barMoveWindow = null
    barMoveScreen = null
  }

  function finishBarMove() {
    var edge = barMoveCandidate
    if (!barMoveActive || !edge || edge === position) {
      clearBarMove()
      return
    }

    clearBarMove()
    setBarPosition(edge)
  }

  function setBarPosition(value) {
    var next = normalizePosition(value)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.position = next
      })
    } else {
      root.position = next
    }
  }

  function captureBarDragGhost(slot) {
    var item = slot && slot.activeItem ? slot.activeItem : null
    barDragImageUrl = ""
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageUrl = result.url
    }, Qt.size(grabWidth, grabHeight))
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  readonly property bool vertical: position === "left" || position === "right"
  // style.size overrides the bar thickness (px); 0/absent keeps the theme's.
  readonly property int barSize: {
    var custom = Math.round(Number(styleConfig.size))
    if (custom >= 16 && custom <= 96) return custom
    return vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  }

  function normalizePosition(value) {
    return BarModel.normalizePosition(value)
  }

  // Apply tray-pinning on top of the shared layout normalization so the
  // bar host and scriptable config helpers can't drift on entry shape.
  function normalizeLayout(layout) {
    var normalized = Util.normalizeLayout(Util.isPlainObject(layout) ? layout : fallbackBarConfig.layout)
    return {
      left:   pinTrayToInner(normalized.left,   "left"),
      center: pinTrayToInner(normalized.center, "center"),
      right:  pinTrayToInner(normalized.right,  "right")
    }
  }

  // The tray drawer reveals inward (away from the bar edge). Place it at the
  // section's inner edge: start of the right section, end of the left/center
  // sections. The drawer's reserved space then sits next to the bar center,
  // not stranded mid-section.
  function pinTrayToInner(entries, section) {
    return BarModel.pinTrayToInner(entries, section)
  }

  function applyBarConfig() {
    var config = Util.isPlainObject(barConfig) ? barConfig : fallbackBarConfig

    position = normalizePosition(config.position)
    setRequestedTransparency(config.transparent === true)
    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")

    // layoutEntries feeds plain JS arrays to the module Repeaters, and QML
    // cannot diff those: reassigning layoutConfig rebuilds every widget on
    // every monitor. When a shell.json write only changed inline widget
    // settings, patch the live layout and running widgets in place instead.
    var next = normalizeLayout(config.layout)
    var delta = BarModel.inlineSettingsDelta(layoutConfig, next)
    if (delta) {
      applySettingsDelta(delta)
      return
    }
    layoutConfig = next
    barConfigSerial++
  }

  function applySettingsDelta(delta) {
    for (var i = 0; i < delta.length; i++) {
      var change = delta[i]
      layoutConfig[change.region][change.index] = change.entry
      var settings = entrySettings(change.entry)
      for (var s = 0; s < moduleSlots.length; s++) {
        var slot = moduleSlots[s]
        if (!slot || slot.region !== change.region || slot.moduleName !== entryId(change.entry)) continue
        var item = slot.activeItem
        if (item && "settings" in item) item.settings = settings
        slot.liveSettings = settings
        if (item) slot.applyIconOverride(item, settings)
      }
    }
  }

  onBarConfigChanged: applyBarConfig()

  function layoutEntries(region) {
    var serial = barConfigSerial
    var entries = layoutConfig ? layoutConfig[region] : null
    return Array.isArray(entries) ? entries : []
  }

  // Tab order for the panels in one bar region. Scoped to a single bar surface
  // so tabbing walks the bar the open panel belongs to instead of hopping the
  // panel to another monitor's copy of the same widget.
  function panelNavigationSlots(region, window) {
    var entries = layoutEntries(region)
    var slots = []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      for (var j = 0; j < moduleSlots.length; j++) {
        var slot = moduleSlots[j]
        if (!slot || slot.region !== region || slot.moduleName !== id) continue
        if (window && !sameWindow(slotWindow(slot), window)) continue
        var item = slot.activeItem
        if (!item || item.visible !== true || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
        if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
        slots.push(slot)
        break
      }
    }
    return slots
  }

  // The Nth panel in a bar region, counted the way the bar reads: layout order,
  // and only the panels actually on screen. A widget with no panel (the tray)
  // and one that is hiding itself are passed over, so the number lands on the
  // Nth panel icon the user can see rather than the Nth layout entry.
  // One-based, because it exists for hotkeys; anything else lands on no slot.
  //
  // Counting any bar surface is enough: every monitor lays its bar out from the
  // one layout, and summoning the id routes through pickPanelSlot, which opens
  // the focused monitor's copy whichever surface was counted.
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotWindow(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = -1
    for (var j = 0; j < slots.length; j++) {
      if (slots[j] === currentSlot) {
        currentIndex = j
        break
      }
    }
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live instance of a widget id. A bar surface is built per monitor, so
  // a widget that appears once in the layout is still live once per screen.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      items.push(slot.activeItem)
    }
    return items
  }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // The output Hyprland has focused, which is where a keyboard-summoned panel
  // belongs. Empty until Hyprland reports one, which leaves panel routing on
  // its per-monitor fallback rather than guessing at an output.
  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  // Resolve the live bar-widget instance for a plugin id (e.g. "omarchy.bluetooth").
  // Only widgets that expose popup open/close methods count; plain indicators
  // (clock, workspaces, tray) return null. Used by shell.summon/toggle so
  // panel hotkeys route through the bar instead of a per-target IPC handler
  // that only reaches whichever per-monitor instance claimed the target.
  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      if (slot.moduleName !== id) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, focusedScreenName())
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  function entrySettings(entry) {
    return BarModel.entrySettings(entry)
  }

  function entryId(entry) {
    return BarModel.entryId(entry)
  }

  function moduleString(entry, key, fallback) {
    return BarModel.moduleString(entry, key, fallback)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }

  function entriesBefore(entries, name) {
    return BarModel.entriesBefore(entries, name)
  }

  function entriesAfter(entries, name) {
    return BarModel.entriesAfter(entries, name)
  }

  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function expandPath(path) {
    return BarModel.expandPath(path, home)
  }

  function customModuleSafeName(name) {
    return BarModel.customModuleSafeName(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  Component.onCompleted: applyBarConfig()

  // Revealing the indicators widens their section, which can slide a neighbour
  // under a stationary pointer. Collapsing on that un-hover would move it back
  // out and re-open the peek, so hold until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerSectionHovered = hovered
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount === 0) centerSectionRevealTimer.restart()
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    // Collapse only. Opening the peek is the center section's own gesture, done
    // in setCenterSectionHovered, so a timer left pending by a pointer that dipped
    // off the bar and came back cannot reveal indicators it never pointed at.
    onTriggered: if (!root.centerSectionHovered && !root.barHovered) root.centerSectionRevealHeld = false
  }

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function toggleTransparency() {
    var nextTransparent = !(root.requestedTransparent === true)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.transparent = nextTransparent
      })
    } else {
      root.setRequestedTransparency(nextTransparent)
    }
  }

  function rawLayoutSection(config, region) {
    if (!Util.isPlainObject(config.bar)) config.bar = {}
    if (!Util.isPlainObject(config.bar.layout)) config.bar.layout = {}
    if (!Array.isArray(config.bar.layout[region])) config.bar.layout[region] = []

    return config.bar.layout[region]
  }

  function rawEntryIndex(entries, name) {
    for (var i = 0; i < entries.length; i++) {
      if (root.entryId(entries[i]) === name) return i
    }

    return -1
  }

  function moveModuleInConfig(config, fromRegion, fromName, toRegion, beforeName) {
    var fromEntries = rawLayoutSection(config, fromRegion)
    var toEntries = rawLayoutSection(config, toRegion)
    var fromIndex = rawEntryIndex(fromEntries, fromName)
    if (fromIndex < 0) return false

    var toIndex = beforeName ? rawEntryIndex(toEntries, beforeName) : toEntries.length
    if (toIndex < 0) toIndex = toEntries.length

    if (fromRegion === toRegion && fromIndex === toIndex) return false

    var movedEntry = fromEntries[fromIndex]
    fromEntries.splice(fromIndex, 1)

    if (fromRegion === toRegion && fromIndex < toIndex) toIndex -= 1
    if (toIndex < 0) toIndex = 0
    if (toIndex > toEntries.length) toIndex = toEntries.length
    if (fromRegion === toRegion && fromIndex === toIndex) {
      fromEntries.splice(fromIndex, 0, movedEntry)
      return false
    }

    toEntries.splice(toIndex, 0, movedEntry)
    return true
  }

  function dropBarModule(source, toRegion, beforeName) {
    if (!source || !source.region || !source.moduleName || !toRegion) return false
    if (source.region === toRegion && source.moduleName === beforeName) return false
    if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

    var changed = false
    root.shell.mutateShellConfig(function(config) {
      changed = moveModuleInConfig(config, source.region, source.moduleName, toRegion, beforeName)
    })
    return changed
  }

  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    if (sourceWindow && sourceWindow.contentItem) {
      var barPoint = sourceWindow.contentItem.mapFromItem(null, scenePoint.x, scenePoint.y)
      if (barPoint.x < 0 || barPoint.x > sourceWindow.contentItem.width ||
          barPoint.y < 0 || barPoint.y > sourceWindow.contentItem.height)
        return null
    }

    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var slotPoint = { x: slot.x, y: slot.y }
      try {
        slotPoint = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }

      candidates.push({
        slot: slot,
        x: slotPoint.x,
        y: slotPoint.y,
        width: slot.width,
        height: slot.height
      })
    }

    return BarModel.nearestDropTarget(candidates, scenePoint, root.vertical)
  }

  function visibleModuleSlot(region, name, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || slot.region !== region || slot.moduleName !== name ||
          !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue
      return slot
    }

    return null
  }

  function nextVisibleModuleName(region, afterName, sourceSlot) {
    var entries = layoutEntries(region)
    var found = false
    for (var i = 0; i < entries.length; i++) {
      var name = entryId(entries[i])
      if (!found) {
        found = name === afterName
        continue
      }

      if (visibleModuleSlot(region, name, sourceSlot)) return name
    }

    return ""
  }

  function dropBarModuleAtTarget(sourceSlot, targetSlot, afterTarget) {
    if (!sourceSlot || !targetSlot) return false

    var beforeName = afterTarget ? nextVisibleModuleName(targetSlot.region, targetSlot.moduleName, sourceSlot) : targetSlot.moduleName
    return dropBarModule(sourceSlot, targetSlot.region, beforeName)
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    target.triggerPress(button)
    return true
  }

  function colorHex(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    function hexChannel(value) {
      var s = Math.round(Util.clamp(value, 0, 1) * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
  }

  function setRequestedTransparency(value) {
    var nextTransparent = value === true
    requestedTransparent = nextTransparent
    if (!nextTransparent) {
      foregroundAnimationEnabled = false
      useTransparentForeground = false
      transparent = false
      transparentForeground = themeForeground
      restoreForegroundAnimation()
      return
    }
    scheduleTransparentForegroundRefresh()
  }

  function restoreForegroundAnimation() {
    Qt.callLater(function() {
      Qt.callLater(function() { root.foregroundAnimationEnabled = true })
    })
  }

  function scheduleTransparentForegroundRefresh() {
    if (!requestedTransparent) {
      transparentForeground = themeForeground
      return
    }
    transparentForegroundTimer.restart()
  }

  function refreshTransparentForeground() {
    if (!requestedTransparent || transparentForegroundProc.running) return

    transparentForegroundProc.command = [
      "omarchy-bar-text-color",
      root.position,
      String(root.barSize),
      colorHex(root.themeForeground),
      colorHex(root.themeContrastForeground)
    ]
    transparentForegroundProc.running = true
  }

  onRequestedTransparentChanged: scheduleTransparentForegroundRefresh()
  onPositionChanged: scheduleTransparentForegroundRefresh()
  onThemeForegroundChanged: scheduleTransparentForegroundRefresh()
  onThemeContrastForegroundChanged: scheduleTransparentForegroundRefresh()

  Timer {
    id: transparentForegroundTimer
    interval: 120
    repeat: false
    onTriggered: root.refreshTransparentForeground()
  }

  Process {
    id: transparentForegroundProc
    stdout: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return

        root.foregroundAnimationEnabled = false
        root.transparentForeground = value
        if (root.requestedTransparent) {
          root.useTransparentForeground = true
          root.transparent = true
        }
        root.restoreForegroundAnimation()
      }
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current"
    watchChanges: true
    printErrors: false
    onFileChanged: root.scheduleTransparentForegroundRefresh()
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // Presence of the `bar-off` flag = bar hidden. Watching the parent toggles
  // directory because FileView can't observe a file that doesn't exist yet,
  // and the flag is created/removed by `omarchy-toggle-bar`.
  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  // The directory watch can permanently stop delivering events after flag
  // changes land in quick succession, stranding the bar off screen until the
  // shell restarts. `omarchy-toggle-bar` nudges this after flipping the flag
  // so the probe re-reads it even when the watch has gone quiet.
  IpcHandler {
    target: "omarchy.bar"

    // Start rather than restart: a probe already in flight was launched by the
    // directory watch after the flag flipped, so its answer is current, and
    // killing it here can swallow the result entirely.
    function syncHidden(): void {
      barHiddenProbe.running = true
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      DragGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarMoveGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    // Hiding parks the bar just past its screen edge instead of unmapping it.
    // Unmapping frees the layer surface and the whole scene graph, so every
    // reveal has to rebuild them — new surface, re-shaped glyphs, re-uploaded
    // textures — which measures ~150ms against ~20ms to tear down. Parking
    // keeps the surface alive, so showing is only a margin change.
    visible: !remapGuard.remapping
    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto

    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }

    margins {
      top: root.barHidden && root.position === "top" ? -root.barSize : (root.position === "top" || root.vertical ? root.segFloat : 0)
      bottom: root.barHidden && root.position === "bottom" ? -root.barSize : (root.position === "bottom" || root.vertical ? root.segFloat : 0)
      left: root.barHidden && root.position === "left" ? -root.barSize : (root.position === "left" || !root.vertical ? root.segFloat : 0)
      right: root.barHidden && root.position === "right" ? -root.barSize : (root.position === "right" || !root.vertical ? root.segFloat : 0)
    }

    anchors {
      top: root.position === "top" || root.vertical
      bottom: root.position === "bottom" || root.vertical
      left: root.position === "left" || !root.vertical
      right: root.position === "right" || !root.vertical
    }

    implicitWidth: root.vertical ? root.barSize : 0
    implicitHeight: root.vertical ? 0 : root.barSize
    color: root.transparent || root.segFloat > 0 ? "transparent" : root.withAlpha(root.background, root.barOpacity)
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    // style.backdrop: a bar-wide panel behind the segments, so a transparent
    // or floating bar still separates from the wallpaper.
    Rectangle {
      anchors.fill: parent
      visible: root.barBackdrop > 0 && (root.transparent || root.segFloat > 0)
      color: Qt.rgba(root.background.r, root.background.g, root.background.b, root.barBackdrop)
      radius: root.segFloat > 0 ? Math.min(root.segRadius, height / 2) : 0
      border.width: root.segFloat > 0 && !root.segActive ? root.segOutline : 0
      border.color: root.segOutlineColor
    }

    // style.outline on a bar without segments, docked: a hairline along the
    // edge that faces the desktop.
    Rectangle {
      visible: root.segOutline > 0 && !root.segActive && root.segFloat === 0
      color: root.segOutlineColor
      width: root.vertical ? root.segOutline : parent.width
      height: root.vertical ? parent.height : root.segOutline
      x: root.position === "left" ? parent.width - width : 0
      y: root.position === "top" ? parent.height - height : 0
      z: 1
    }

    Loader {
      anchors.fill: parent
      sourceComponent: root.vertical ? verticalBar : horizontalBar

      // A child of the loader, not a sibling of the sections: an ancestor stays
      // hovered while the pointer is over a widget, where a sibling would lose
      // hover to the section the pointer entered.
      HoverHandler {
        onHoveredChanged: root.setBarHovered(hovered)
        // Unplugging a monitor destroys its bar without a leave event, which
        // would strand this surface's tally and hold the peek open for good.
        Component.onDestruction: if (hovered) root.setBarHovered(false)
      }
    }

    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var popupWidth = tooltipWindow.implicitWidth
          var popupHeight = tooltipWindow.implicitHeight
          var localX = target.width / 2 - popupWidth / 2
          var localY = target.height + 6

          if (root.position === "bottom") {
            localY = -popupHeight - 6
          } else if (root.position === "left") {
            localX = target.width + 6
            localY = target.height / 2 - popupHeight / 2
          } else if (root.position === "right") {
            localX = -popupWidth - 6
            localY = target.height / 2 - popupHeight / 2
          }

          var point = barWindow.contentItem.mapFromItem(target, localX, localY)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Commons.Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.tooltipText
          color: Commons.Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Component {
      id: horizontalBar

      Item {
        anchors.fill: parent

        CenterModules { anchors.fill: parent }

        LeftModules {
          anchors.left: parent.left
          anchors.leftMargin: root.segEdge
          anchors.verticalCenter: parent.verticalCenter
        }

        RightModules {
          anchors.right: parent.right
          anchors.rightMargin: root.segEdge
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Component {
      id: verticalBar

      Item {
        anchors.fill: parent

        CenterModules { anchors.fill: parent }

        LeftModules {
          anchors.top: parent.top
          anchors.topMargin: root.segEdge
          anchors.horizontalCenter: parent.horizontalCenter
        }

        RightModules {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.segEdge
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }

  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }

  component DragGhostPanel: PanelWindow {
    id: ghostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barDragScreen === ghostScreen ||
      (root.barDragScreen && ghostScreen && root.barDragScreen.name && ghostScreen.name && root.barDragScreen.name === ghostScreen.name)
    readonly property bool active: root.barDragSource && root.barDragScreen && screenMatches
    readonly property var sourceItem: root.barDragSource ? root.barDragSource.activeItem : null
    readonly property int ghostPadding: Style.space(1)
    readonly property int ghostWidth: sourceItem ? Math.max(1, Math.ceil(sourceItem.width)) : 1
    readonly property int ghostHeight: sourceItem ? Math.max(1, Math.ceil(sourceItem.height)) : 1

    visible: active && sourceItem !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only drag feedback. Keep the input region empty so the ghost can
    // sit under the cursor without stealing the MouseArea's active pointer grab.
    mask: Region {}

    Item {
      visible: ghostWindow.visible
      x: Math.round(root.barDragScreenX - root.barDragOffsetX - ghostWindow.ghostPadding)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY - ghostWindow.ghostPadding)
      width: ghostWindow.ghostWidth + ghostWindow.ghostPadding * 2
      height: ghostWindow.ghostHeight + ghostWindow.ghostPadding * 2

      BorderSurface {
        anchors.fill: parent
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        radius: Math.min(Style.cornerRadius, height / 2)
        opacity: root.transparent ? 0.45 : 0.94
      }

      Image {
        anchors.fill: parent
        anchors.margins: ghostWindow.ghostPadding
        source: root.barDragImageUrl
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.84
      }
    }

    Rectangle {
      readonly property var targetRect: root.barDragTargetGeometry

      visible: ghostWindow.active && targetRect !== null
      x: targetRect ? Math.round(targetRect.x) : 0
      y: targetRect ? Math.round(targetRect.y) : 0
      width: targetRect ? targetRect.width : 0
      height: targetRect ? targetRect.height : 0
      color: root.segAccent
      radius: Math.min(width, height) / 2
    }
  }

  component BarMoveGhostPanel: PanelWindow {
    id: moveGhostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barMoveScreen === ghostScreen ||
      (root.barMoveScreen && ghostScreen && root.barMoveScreen.name && ghostScreen.name && root.barMoveScreen.name === ghostScreen.name)
    visible: root.barMoveActive && screenMatches
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-move-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only preview of the candidate edge. Keep the input region empty
    // so the overlay never steals the gesture area's active pointer grab.
    mask: Region {}

    // One fixed-geometry slab per edge, crossfaded on candidate changes.
    // Resizing a single slab between edges repaints mid-transition and
    // flickers; fading between static ones does not.
    Repeater {
      model: ["top", "bottom", "left", "right"]

      BorderSurface {
        id: edgeSlab

        required property string modelData
        readonly property bool edgeVertical: modelData === "left" || modelData === "right"
        readonly property int edgeSize: edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal

        x: modelData === "right" ? parent.width - edgeSize : 0
        y: modelData === "bottom" ? parent.height - edgeSize : 0
        width: edgeVertical ? edgeSize : parent.width
        height: edgeVertical ? parent.height : edgeSize
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        visible: opacity > 0
        opacity: root.barMoveCandidate === modelData ? (root.transparent ? 0.45 : 0.7) : 0

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  function findCenterAnchorEntry() {
    var entries = root.layoutEntries("center")
    var idx = root.entryIndex(entries, root.centerAnchor)
    return idx === -1 ? null : entries[idx]
  }

  component LeftModules: ModuleList {
    entries: root.layoutEntries("left")
    region: "left"
  }

  component RightModules: ModuleList {
    entries: root.layoutEntries("right")
    region: "right"
  }

  component CenterModules: Item {
    id: centerRoot

    property var entries: root.layoutEntries("center")
    readonly property bool hasAnchor: root.entryIndex(entries, root.centerAnchor) !== -1
    readonly property var anchorEntry: root.findCenterAnchorEntry()
    readonly property int anchorIdx: root.entryIndex(entries, root.centerAnchor)

    Loader {
      anchors.fill: parent
      sourceComponent: root.vertical ? verticalCenterModules : horizontalCenterModules
    }

    Component {
      id: horizontalCenterModules

      Item {
        anchors.fill: parent

        CenterGestureArea { anchors.fill: parent }

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        ModuleList {
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          anchorIndex: -1
          anchors.centerIn: parent
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          indexBase: 0
          regionTotal: centerRoot.entries.length
          anchorIndex: centerRoot.anchorIdx
          anchors.right: centerAnchorModule.left
          anchors.verticalCenter: centerAnchorModule.verticalCenter
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          regionIndex: centerRoot.anchorIdx
          regionCount: centerRoot.entries.length
          anchorIndex: centerRoot.anchorIdx
          anchors.centerIn: parent
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          indexBase: centerRoot.anchorIdx + 1
          regionTotal: centerRoot.entries.length
          anchorIndex: centerRoot.anchorIdx
          anchors.left: centerAnchorModule.right
          anchors.verticalCenter: centerAnchorModule.verticalCenter
        }
      }
    }

    Component {
      id: verticalCenterModules

      Item {
        anchors.fill: parent

        CenterGestureArea { anchors.fill: parent }

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        ModuleList {
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          anchorIndex: -1
          anchors.centerIn: parent
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          indexBase: 0
          regionTotal: centerRoot.entries.length
          anchorIndex: centerRoot.anchorIdx
          anchors.bottom: centerAnchorModule.top
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          regionIndex: centerRoot.anchorIdx
          regionCount: centerRoot.entries.length
          anchorIndex: centerRoot.anchorIdx
          anchors.centerIn: parent
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          indexBase: centerRoot.anchorIdx + 1
          regionTotal: centerRoot.entries.length
          anchorIndex: centerRoot.anchorIdx
          anchors.top: centerAnchorModule.bottom
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }
      }
    }
  }

  component CenterGestureArea: MouseArea {
    id: gestureArea

    property bool dragging: false
    property bool suppressClick: false
    property real pressedX: 0
    property real pressedY: 0
    readonly property real dragThreshold: Style.space(4)

    acceptedButtons: Qt.LeftButton
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
    pressAndHoldInterval: 200

    function startDrag(x, y) {
      if (dragging) return
      dragging = true
      root.beginBarMove(root.targetWindow(gestureArea))
      var scenePoint = gestureArea.mapToItem(null, x, y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onPressed: function(mouse) {
      dragging = false
      suppressClick = false
      pressedX = mouse.x
      pressedY = mouse.y
    }

    onPressAndHold: function(mouse) {
      // A widget above us propagates its composed press-and-hold down here without
      // ever handing over the grab, so we'd get no release or cancel to end the move.
      if (!gestureArea.pressed) return
      startDrag(mouse.x, mouse.y)
    }

    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return

      if (!dragging) {
        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance < dragThreshold) return
        startDrag(mouse.x, mouse.y)
        return
      }

      var scenePoint = gestureArea.mapToItem(null, mouse.x, mouse.y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onReleased: function(mouse) {
      if (!dragging) return
      dragging = false
      suppressClick = true
      root.finishBarMove()
      mouse.accepted = true
    }

    onCanceled: {
      dragging = false
      suppressClick = false
      root.clearBarMove()
    }

    onClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        mouse.accepted = true
      }
    }

    onDoubleClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        return
      }
      if (mouse.button === Qt.LeftButton) {
        root.toggleTransparency()
        mouse.accepted = true
      }
    }
  }

  component ModuleList: Loader {
    id: moduleListRoot

    property var entries: []
    property string region: ""
    property int indexBase: 0
    property int regionTotal: entries.length
    property int anchorIndex: -1

    visible: entries.length > 0
    // A hidden list must not build its modules. The center section declares
    // both an anchored and an unanchored arrangement and shows whichever
    // fits, so leaving the other one loaded mounts every center module
    // twice — two IPC handlers registered for the same target, two clocks
    // ticking, two of every timer and fetch behind them.
    active: visible && entries.length > 0
    sourceComponent: root.vertical ? verticalModuleList : horizontalModuleList
    width: item ? item.implicitWidth : 0
    height: item ? item.implicitHeight : 0

    Component {
      id: horizontalModuleList

      Row {
        spacing: 0

        Repeater {
          model: moduleListRoot.entries

          ModuleSlot {
            required property var modelData
            required property int index
            entry: modelData
            region: moduleListRoot.region
            regionIndex: moduleListRoot.indexBase + index
            regionCount: moduleListRoot.regionTotal
            anchorIndex: moduleListRoot.anchorIndex
          }
        }
      }
    }

    Component {
      id: verticalModuleList

      Column {
        spacing: 0

        Repeater {
          model: moduleListRoot.entries

          ModuleSlot {
            required property var modelData
            required property int index
            entry: modelData
            region: moduleListRoot.region
            regionIndex: moduleListRoot.indexBase + index
            regionCount: moduleListRoot.regionTotal
            anchorIndex: moduleListRoot.anchorIndex
          }
        }
      }
    }
  }

  component ModuleSlot: Item {
    id: slot

    // >>> modarchy: hidden bar icons
    readonly property bool modarchyHidden: root.modarchyHiddenIds.indexOf(moduleName) !== -1
    visible: !modarchyHidden
    // <<< modarchy
    required property var entry
    property string region: ""
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    // Settings-only edits arrive through applySettingsDelta without a new
    // entry; the look below reads them from here.
    property var liveSettings: null
    onEntryChanged: liveSettings = null
    readonly property var lookSettings: liveSettings || moduleSettings
    readonly property string customType: root.customModuleType(entry)
    readonly property var registryMetadata: root.barWidgetRegistry.metadataFor(root.canonicalWidgetId(moduleName))
    readonly property bool firstParty: registryMetadata && registryMetadata.firstParty === true
    readonly property string pluginApiId: registered ? root.canonicalWidgetId(moduleName) : "bar-entry:" + moduleName
    // Re-evaluate when the registry mutates (Component reference changes,
    // plugin enabled/disabled, etc.). Reading the `widgets` property creates
    // the binding dependency — the wrapped function call alone wouldn't.
    readonly property var registryComponent: {
      var w = root.barWidgetRegistry.widgets
      if (customType) return null
      var registryName = root.canonicalWidgetId(moduleName)
      return w[registryName] ? w[registryName].component : null
    }
    readonly property bool qmlCustom: customType === "qml"
    readonly property bool commandCustom: customType === "command"
    readonly property bool registered: registryComponent !== null
    readonly property var activeItem: {
      if (registered) return registryLoader.item
      if (qmlCustom) return qmlLoader.item
      return componentLoader.item
    }
    readonly property bool hovered: moduleHover.hovered
    readonly property bool dragSource: root.barDragSource === slot
    readonly property bool panelOpen: root.activePopout === slot.activeItem
    // Modules bigger than the mark they want (a text label in a padded slot,
    // a multi-line stack on a vertical bar) can say how long the open-panel
    // dot should be along the bar, so it tracks what the module paints
    // instead of a fraction of whatever slot it happens to fill.
    readonly property real panelIndicatorExtent: {
      var key = root.vertical ? "openPanelIndicatorHeight" : "openPanelIndicatorWidth"
      var hint = activeItem && key in activeItem ? activeItem[key] : undefined
      if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
      return Math.max(Style.space(10), Math.round((root.vertical ? slot.height : slot.width) * 0.55))
    }
    // ---- segment geometry (see the "Segment styling" block on root)
    //
    // A styled slot is: [pad-left | widget | pad-right], minus the overlap
    // that lets one segment's point sit inside its neighbour's notch. The
    // segment shape is drawn `segBase` wide and may poke outside the slot by
    // exactly that overlap, so hidden (zero width) widgets never disturb the
    // nesting of the visible ones.
    // Supplied by the owning ModuleList; a slot must not read layoutEntries()
    // itself, or every slot re-evaluates while its list is being rebuilt.
    property int regionIndex: 0
    property int regionCount: 1
    property int anchorIndex: -1
    readonly property bool segmented: root.segActive && moduleName !== "omarchy.spacer"
    readonly property bool segmentedH: segmented && !root.vertical
    readonly property real contentW: activeItem && activeItem.visible ? (root.vertical ? root.barSize : activeItem.implicitWidth) : 0
    readonly property real contentH: activeItem && activeItem.visible ? activeItem.implicitHeight : 0
    readonly property int shapeH: Math.max(1, Math.round(root.barSize - 2 * root.segInset))
    // Which way this segment's point faces. Left of the centre and the whole
    // right section point left, the left section and the right half of the
    // centre point right, and the centre anchor is a hexagon pointing both
    // ways, so the centre fans outward from it.
    readonly property string arrowMode: {
      if (root.segKind !== "arrow") return "right"
      if (region === "right") return "left"
      if (region === "center") {
        var a = anchorIndex
        if (a < 0) return "right"
        return regionIndex < a ? "left" : (regionIndex === a ? "both" : "right")
      }
      return "right"
    }
    readonly property int dir: arrowMode === "left" ? -1 : 1
    readonly property int depth: !segmentedH ? 0
      : (root.segKind === "arrow" ? Math.max(2, Math.round(shapeH * root.segDepth))
      : (root.segKind === "hex" ? Math.max(2, Math.round(shapeH * root.segDepth * 0.6))
      : (["slant", "backslant", "trapezoid"].indexOf(root.segKind) >= 0 ? Math.max(2, Math.round(shapeH * 0.32)) : 0)))
    readonly property bool flatEdge: root.segKind === "arrow" && root.segFlatEnds
      && ((region === "left" && regionIndex === 0) || (region === "right" && regionIndex === regionCount - 1))
    readonly property int notchDepth: flatEdge ? 0 : depth
    readonly property int basePad: root.segKind === "round" ? Math.round(shapeH * 0.3) : root.segPad
    readonly property int padL: !segmentedH ? 0 : (arrowMode === "right" ? notchDepth : depth) + basePad
    readonly property int padR: !segmentedH ? 0 : (arrowMode === "left" ? notchDepth : depth) + basePad
    readonly property real segBase: contentW > 0 ? contentW + padL + padR : 0
    // Slants nest into their neighbours; trapezoids and hexagons stand apart.
    readonly property bool standsApart: root.segKind === "trapezoid" || root.segKind === "hex"
    readonly property real segOverlap: standsApart ? -root.segGap : depth - root.segGap
    // How far the shape reaches into each neighbour's notch.
    readonly property real pokeLeft: arrowMode === "left" || arrowMode === "both" ? segOverlap : 0
    readonly property real pokeRight: arrowMode === "right" || arrowMode === "both" ? segOverlap : 0
    readonly property real shapeX: -pokeLeft
    readonly property real contentX: segmentedH ? shapeX + padL : 0
    readonly property real loaderW: segmentedH ? contentW : width
    readonly property color segBaseColor: root.segmentColor(region, regionIndex, regionCount, moduleName)
    // Hover: the module's own colour, else the bar's; without either the
    // segment just lightens as before.
    readonly property bool ownHover: lookSettings && root.validHex(lookSettings.hoverColor)
    readonly property bool hoverCustom: ownHover || root.hoverStyled
    readonly property color hoverTint: ownHover ? Qt.color(lookSettings.hoverColor) : root.hoverColor
    readonly property bool lit: (hovered || panelOpen) && !dragSource
    readonly property color segFill: root.withAlpha(hoverCustom && lit
      ? root.mixColors(root.segmentFill(segBaseColor, false), hoverTint, root.hoverOpacity)
      : root.segmentFill(segBaseColor, hovered || panelOpen), root.segOpacity * moduleOpacity)
    readonly property real moduleOpacity: {
      var v = lookSettings ? Number(lookSettings.opacity) : NaN
      return isFinite(v) && v > 0 ? Math.max(0.1, Math.min(1, v)) : 1
    }
    readonly property var segPoints: {
      var w = segBase, h = shapeH, d = depth, n = notchDepth
      if (root.segKind === "slant")
        return [Qt.point(d, 0), Qt.point(w, 0), Qt.point(w - d, h), Qt.point(0, h)]
      if (root.segKind === "backslant")
        return [Qt.point(0, 0), Qt.point(w - d, 0), Qt.point(w, h), Qt.point(d, h)]
      if (root.segKind === "trapezoid")
        return [Qt.point(0, 0), Qt.point(w, 0), Qt.point(w - d, h), Qt.point(d, h)]
      if (root.segKind === "hex" || arrowMode === "both")
        return [Qt.point(d, 0), Qt.point(w - d, 0), Qt.point(w, h / 2), Qt.point(w - d, h), Qt.point(d, h), Qt.point(0, h / 2)]
      var pts = [Qt.point(0, 0), Qt.point(w - d, 0), Qt.point(w, h / 2), Qt.point(w - d, h), Qt.point(0, h)]
      if (n > 0) pts.push(Qt.point(n, h / 2))
      return pts
    }

    implicitWidth: contentW <= 0 ? 0 : (segmentedH ? segBase - pokeLeft - pokeRight : contentW)
    implicitHeight: contentH
    width: implicitWidth
    height: implicitHeight
    z: modulePointer.dragging ? 100 : 0

    Component.onCompleted: root.registerModuleSlot(slot)
    Component.onDestruction: {
      if (root.barDragSource === slot) root.clearBarDrag()
      root.unregisterModuleSlot(slot)
    }

    HoverHandler { id: moduleHover }

    Rectangle {
      visible: !slot.segmented && slot.hoverCustom && slot.width > 0
      anchors.fill: parent
      anchors.topMargin: Style.space(3)
      anchors.bottomMargin: Style.space(3)
      radius: Math.min(Style.cornerRadius, height / 2)
      color: slot.hoverTint
      opacity: slot.lit ? root.hoverOpacity : 0
      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    readonly property bool polygonSegment: slot.segmentedH && slot.width > 0
      && ["arrow", "slant", "backslant", "trapezoid", "hex"].indexOf(root.segKind) >= 0
    readonly property bool boxSegment: slot.segmented && slot.width > 0
      && ["round", "block", "leaf", "tab", "underline"].indexOf(root.segKind) >= 0
    readonly property var closedPoints: slot.segPoints.concat([slot.segPoints[0]])
    readonly property color shadowColor: Qt.rgba(0, 0, 0, root.segShadow * 0.6 * root.segOpacity * slot.moduleOpacity)

    // style.shadow: the segment's silhouette, offset away from the wallpaper's
    // light, drawn under the segment itself.
    Shape {
      id: segmentShadow
      visible: slot.polygonSegment && root.segShadow > 0
      x: slot.shapeX
      y: Math.round((slot.height - slot.shapeH) / 2) + root.segShadowOffset
      width: slot.segBase
      height: slot.shapeH
      preferredRendererType: Shape.CurveRenderer
      transform: Scale { origin.x: segmentShadow.width / 2; xScale: slot.dir < 0 ? -1 : 1 }

      ShapePath {
        fillColor: slot.shadowColor
        strokeWidth: -1
        PathPolyline { path: slot.segPoints }
      }
    }

    Rectangle {
      visible: slot.boxSegment && root.segShadow > 0
      x: boxFill.x
      y: boxFill.y + root.segShadowOffset
      width: boxFill.width
      height: boxFill.height
      radius: boxFill.radius
      topLeftRadius: boxFill.topLeftRadius
      topRightRadius: boxFill.topRightRadius
      bottomLeftRadius: boxFill.bottomLeftRadius
      bottomRightRadius: boxFill.bottomRightRadius
      color: slot.shadowColor
    }

    Shape {
      id: segmentShape
      visible: slot.polygonSegment
      x: slot.shapeX
      y: Math.round((slot.height - slot.shapeH) / 2)
      width: slot.segBase
      height: slot.shapeH
      preferredRendererType: Shape.CurveRenderer
      transform: Scale { origin.x: segmentShape.width / 2; xScale: slot.dir < 0 ? -1 : 1 }

      ShapePath {
        fillColor: slot.segFill
        strokeWidth: root.segOutline > 0 ? root.segOutline : -1
        strokeColor: root.segOutlineColor
        joinStyle: ShapePath.MiterJoin
        PathPolyline { path: root.segOutline > 0 ? slot.closedPoints : slot.segPoints }
      }
    }

    Rectangle {
      id: boxFill
      readonly property real fullH: slot.segmentedH ? slot.shapeH : slot.height - Style.space(2)
      readonly property real topY: slot.segmentedH ? Math.round((slot.height - slot.shapeH) / 2) : Style.space(1)
      // An underline is a bar under the module, the rest fill the segment.
      readonly property real lineH: Math.max(2, Math.round(fullH * 0.12))
      readonly property real baseR: root.segKind === "round" ? Math.min(width, height) / 2 : Math.min(root.segRadius, height / 2)
      readonly property real bigR: Math.min(width, height) / 2
      visible: slot.boxSegment
      x: slot.segmentedH ? slot.shapeX : Style.space(2)
      y: root.segKind === "underline" ? topY + fullH - lineH : topY
      width: slot.segmentedH ? slot.segBase : slot.width - Style.space(4)
      height: root.segKind === "underline" ? lineH : fullH
      radius: root.segKind === "underline" ? lineH / 2 : baseR
      // Leaf: two opposite corners fully round. Tab: round on top, square below.
      topLeftRadius: root.segKind === "leaf" ? bigR : root.segKind === "tab" ? Math.max(baseR, Math.min(10, height / 2)) : radius
      bottomRightRadius: root.segKind === "leaf" ? bigR : root.segKind === "tab" ? 0 : radius
      topRightRadius: root.segKind === "leaf" ? Math.min(2, radius) : root.segKind === "tab" ? Math.max(baseR, Math.min(10, height / 2)) : radius
      bottomLeftRadius: root.segKind === "leaf" ? Math.min(2, radius) : root.segKind === "tab" ? 0 : radius
      color: slot.segFill
      border.width: root.segOutline
      border.color: root.segOutlineColor
    }

    BorderSurface {
      visible: slot.dragSource
      anchors.fill: parent
      anchors.margins: Style.space(1)
      color: root.transparent ? "transparent" : root.background
      borderSpec: Border.flat(root.barForeground, 1)
      radius: Math.min(Style.cornerRadius, height / 2)
      opacity: root.transparent ? 0.22 : 0.32
    }

    Loader {
      id: componentLoader
      active: !slot.qmlCustom && !slot.registered
      sourceComponent: slot.commandCustom ? customCommandModuleComponent : emptyModuleComponent
      x: slot.contentX
      width: slot.loaderW
      height: parent.height
      opacity: slot.dragSource ? 0.22 : slot.moduleOpacity
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: registryLoader
      active: slot.registered
      sourceComponent: slot.registered ? slot.registryComponent : null
      x: slot.contentX
      width: slot.loaderW
      height: parent.height
      opacity: slot.dragSource ? 0.22 : slot.moduleOpacity
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: qmlLoader
      active: slot.qmlCustom
      source: slot.qmlCustom ? root.customModuleSource(slot.entry) : ""
      x: slot.contentX
      width: slot.loaderW
      height: parent.height
      opacity: slot.dragSource ? 0.22 : slot.moduleOpacity
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Rectangle {
      id: openPanelIndicator

      readonly property int inset: Style.space(2)

      visible: opacity > 0
      opacity: slot.panelOpen && !slot.dragSource ? 0.9 : 0
      color: root.segAccent
      radius: Math.min(width, height) / 2
      width: root.vertical ? Style.space(2) : slot.panelIndicatorExtent
      height: root.vertical ? slot.panelIndicatorExtent : Style.space(2)
      // The mark sits on the module's inner edge — the one facing the
      // desktop — so it underlines a top bar, overlines a bottom one, and
      // points inward from a left or right one. It reads as pointing at the
      // panel that opens on that side.
      x: root.vertical
        ? (root.position === "left" ? parent.width - width - inset : inset)
        : Math.round((parent.width - width) / 2)
      y: root.vertical
        ? Math.round((parent.height - height) / 2)
        : (root.position === "top" ? parent.height - height - inset : inset)
      z: 50

      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      id: modulePointer

      property bool dragging: false
      property bool suppressClick: false
      property real pressedX: 0
      property real pressedY: 0
      readonly property bool canReorder: root.shell && typeof root.shell.mutateShellConfig === "function"
      readonly property real dragThreshold: Style.space(4)

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      enabled: slot.visible && slot.width > 0 && slot.height > 0
      propagateComposedEvents: true
      cursorShape: root.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
      // Do not assign drag.target here: ModuleSlot is owned by Row/Column
      // positioners, and mutating slot.x/slot.y can leave stale offsets that
      // make neighboring modules overlap after a small aborted drag.

      onPressed: function(mouse) {
        dragging = false
        suppressClick = false
        pressedX = mouse.x
        pressedY = mouse.y
        root.clearBarDrag()
      }

      onPositionChanged: function(mouse) {
        if (!canReorder || !(mouse.buttons & Qt.LeftButton)) return

        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance >= dragThreshold) {
          if (!dragging) {
            root.barDragWindow = root.targetWindow(slot.activeItem) || root.targetWindow(slot)
            root.barDragScreen = root.barDragWindow ? root.barDragWindow.screen : null
            root.barDragOffsetX = pressedX
            root.barDragOffsetY = pressedY
            root.captureBarDragGhost(slot)
            root.barDragSource = slot
          }
          dragging = true
          root.hideTooltip(slot.activeItem)
        }

        if (dragging) {
          var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
          var screenPoint = root.barDragScreenPoint(scenePoint)
          root.barDragSceneX = scenePoint.x
          root.barDragSceneY = scenePoint.y
          root.barDragScreenX = screenPoint.x
          root.barDragScreenY = screenPoint.y

          var drop = root.moduleDropAtScene(scenePoint, slot)
          root.barDragTarget = drop ? drop.slot : null
          root.barDragAfter = drop ? drop.after : false
          root.barDragTargetGeometry = drop ? root.dropMarkerRect(drop.slot, drop.after) : null
        }
      }

      onReleased: function(mouse) {
        var wasDragging = dragging
        var targetSlot = root.barDragTarget
        var afterTarget = root.barDragAfter

        if (wasDragging) suppressClick = true

        dragging = false
        root.clearBarDrag()

        if (wasDragging && targetSlot) {
          root.dropBarModuleAtTarget(slot, targetSlot, afterTarget)
          mouse.accepted = true
        } else if (!wasDragging) {
          mouse.accepted = false
        }
      }

      onCanceled: {
        dragging = false
        suppressClick = false
        root.clearBarDrag()
      }

      onClicked: function(mouse) {
        if (suppressClick) {
          suppressClick = false
          mouse.accepted = true
          return
        }

        if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
      }
    }

    onActiveItemChanged: Qt.callLater(injectProps)
    onModuleSettingsChanged: injectProps()

    function injectProps() {
      var target = activeItem
      if (!target) return
      if ("bar" in target) target.bar = firstParty
        ? root : root.pluginBarApiFor(pluginApiId, moduleName, registered)
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
      applyIconOverride(target)
    }

    // Per-module look, applied to the widget's glyph button: entry.icon
    // replaces its glyph (in entry.iconFont), entry.font sets its text font
    // and entry.color its colour. What the button had is remembered, so
    // clearing a setting puts it back.
    property var iconButton: null
    property string defaultIconText: ""
    property string defaultIconFont: ""
    property bool iconOverridden: false
    property bool fontOverridden: false
    property bool colorOverridden: false
    property var overrideTarget: null

    // The first item (the widget itself, or a child) that has both a text and
    // a fontFamily: that is the WidgetButton drawing the glyph.
    function findIconButton(item, depth) {
      if (!item) return null
      if ("text" in item && "fontFamily" in item) return item
      if (depth > 3) return null
      var kids = item.children || []
      for (var i = 0; i < kids.length; i++) {
        var hit = findIconButton(kids[i], depth + 1)
        if (hit) return hit
      }
      return null
    }

    function cfgString(cfg, key) {
      var v = cfg ? cfg[key] : undefined
      return typeof v === "string" ? v.trim() : ""
    }

    function applyIconOverride(target, settings) {
      var cfg = settings !== undefined ? settings : moduleSettings
      var icon = cfgString(cfg, "icon")
      var font = cfgString(cfg, "font")
      var iconFont = cfgString(cfg, "iconFont")
      var color = cfgString(cfg, "color")
      var wants = icon !== "" || font !== "" || root.validHex(color)
      // A reloaded widget is a new item: forget the old button.
      if (target && target !== overrideTarget) {
        overrideTarget = target
        iconButton = null
        iconOverridden = fontOverridden = colorOverridden = false
      }
      if (!iconButton && !wants) return
      var btn = iconButton || findIconButton(target, 0)
      if (!btn) return
      if (!iconButton) {
        iconButton = btn
        defaultIconText = btn.text
        defaultIconFont = btn.fontFamily
      }

      if (icon !== "") {
        if (!iconOverridden) defaultIconText = btn.text
        btn.text = icon
        iconOverridden = true
      } else if (iconOverridden) {
        btn.text = defaultIconText
        iconOverridden = false
      }

      // A custom icon uses the icon font; otherwise entry.font, else the
      // button's own font (the stock glyph font for icon-only widgets).
      var family = icon !== "" ? (iconFont || root.iconFontFamily) : font
      if (family !== "") {
        btn.fontFamily = family
        fontOverridden = true
      } else if (fontOverridden) {
        btn.fontFamily = defaultIconFont
        fontOverridden = false
      }

      if ("foreground" in btn) {
        if (root.validHex(color)) {
          btn.foreground = Qt.color(color)
          colorOverridden = true
        } else if (colorOverridden) {
          var b = btn
          btn.foreground = Qt.binding(function() { return b.bar ? b.bar.barForeground : Commons.Color.foreground })
          colorOverridden = false
        }
      }
    }

    Component {
      id: customCommandModuleComponent
      CustomCommandModule { entry: slot.entry }
    }
  }

  component CustomCommandModule: WidgetButton {
    id: customRoot

    required property var entry
    readonly property string moduleName: root.entryId(entry)
    readonly property var settings: root.entrySettings(entry)
    property string outputText: ""
    property string outputTooltip: ""
    property bool outputActive: false

    function setting(name, fallback) {
      var value = settings ? settings[name] : undefined
      return value === undefined || value === null ? fallback : value
    }

    function update(raw) {
      var data = Util.parseModuleJson(raw)
      var klass = data.class || data.alt || ""

      outputText = data.text || String(raw || "").trim()
      outputTooltip = data.tooltip || String(setting("tooltip", ""))
      outputActive = klass === "active" || (Array.isArray(klass) && klass.indexOf("active") !== -1)
    }

    bar: root
    text: outputText || String(setting("text", ""))
    tooltipText: outputTooltip || String(setting("tooltip", ""))
    active: outputActive
    keepSpace: setting("keepSpace", false) === true
    horizontalMargin: Number(setting("horizontalMargin", 7.5))
    verticalPadding: Number(setting("verticalPadding", 6))
    fontSize: Number(setting("fontSize", 12))

    onPressed: function(button) {
      var command = ""
      if (button === Qt.RightButton)
        command = String(setting("onRightClick", ""))
      else if (button === Qt.MiddleButton)
        command = String(setting("onMiddleClick", ""))
      else
        command = String(setting("onClick", ""))

      if (command) root.run(command)
    }

    Process {
      id: customProc
      command: ["bash", "-lc", String(customRoot.setting("exec", ""))]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: customRoot.update(text)
      }
    }

    Timer {
      interval: Math.max(1, Number(customRoot.setting("interval", 5))) * 1000
      running: String(customRoot.setting("exec", "")) !== ""
      repeat: true
      triggeredOnStart: true
      onTriggered: root.runProcess(customProc)
    }
  }
}

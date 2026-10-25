import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Commons as Commons

// Burn My Windows for the Omarchy shell: effects when windows open and close,
// after the GNOME extension of the same name.
//
// Hyprland can't run a shader on a single window, so the shell does it: it
// captures the window with ScreencopyView, hides the real one (opacity 0, no
// Hyprland animation), and plays the effect over the copy on a click-through
// layer. Opening windows are caught from Hyprland's openwindow event. Closing
// needs the window's last frame before it goes, so closing goes through
// `omarchy-shell burn close` (the plugin binds SUPER+W and SUPER+Q to it);
// windows that close any other way get Hyprland's usual animation.
//
// Settings: ~/.config/omarchy/burn-my-windows.json, applied live.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
  readonly property string settingsPath: configHome + "/omarchy/burn-my-windows.json"
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl("effects.json").toString().replace(/^file:\/\//, "").replace(/effects\.json$/, ""))
  readonly property string helper: pluginDir + "bin/burn-window"

  readonly property var defaults: ({
    enabled: true,
    open: { enabled: true, effects: ["glide"], speed: 1.0 },
    close: { enabled: true, effects: ["fire"], speed: 1.0 },
    intensity: 1.0,
    color: "effect",
    exclude: ["org.omarchy.screensaver"],
    skipFloating: false,
    skipFullscreen: true
  })

  property var catalog: []
  property var settings: defaults
  readonly property var openSettings: Object.assign({}, defaults.open, settings.open || {})
  readonly property var closeSettings: Object.assign({}, defaults.close, settings.close || {})

  // Windows being handled, by address, so one window never gets two effects.
  property var active: ({})

  // ------------------------------------------------------------- settings

  FileView {
    path: root.pluginDir + "effects.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.catalog = JSON.parse(text()).effects || [] }
      catch (e) { console.warn("burn: effects.json:", e) }
    }
  }

  FileView {
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      // A write in place can be seen half done; the next change brings the rest.
      if (!text().trim()) return
      try { root.settings = Object.assign({}, root.defaults, JSON.parse(text())) }
      catch (e) { console.warn("burn: " + root.settingsPath + ":", e) }
    }
    onLoadFailed: root.settings = root.defaults
  }

  function effectDef(id) {
    for (let i = 0; i < catalog.length; i++)
      if (catalog[i].id === id) return catalog[i]
    return null
  }

  // A random effect from the list; "random" in the list means any effect.
  function pickEffect(list) {
    let ids = (Array.isArray(list) ? list : [list]).map(String)
    if (ids.indexOf("random") !== -1) ids = catalog.map(e => e.id)
    ids = ids.filter(id => effectDef(id))
    if (!ids.length) return null
    return effectDef(ids[Math.floor(Math.random() * ids.length)])
  }

  function tintFor(def) {
    const choice = String(settings.color || "effect")
    if (choice === "theme") return [Commons.Color.accent, Qt.lighter(Commons.Color.accent, 1.5)]
    if (/^#[0-9a-fA-F]{6,8}$/.test(choice)) return [choice, Qt.lighter(choice, 1.5)]
    return [def.color || "white", def.color2 || "white"]
  }

  function excluded(info) {
    const skip = settings.exclude || []
    if (skip.indexOf(info.class) !== -1) return true
    if (settings.skipFloating && info.floating) return true
    if (settings.skipFullscreen && info.fullscreen) return true
    return false
  }

  // ------------------------------------------------------------- hyprland

  function bare(address) { return String(address || "").replace(/^0x/, "") }

  function toplevelFor(address) {
    const want = bare(address)
    const list = Hyprland.toplevels.values
    for (let i = 0; i < list.length; i++)
      if (bare(list[i].address) === want) return list[i]
    return null
  }

  function dispatch(lua) { Hyprland.dispatch(lua) }
  function closeNow(address) {
    dispatch(address ? 'hl.dsp.window.close({ window = "address:0x' + bare(address) + '" })' : "hl.dsp.window.close()")
  }
  function setNoAnim(address, on) {
    dispatch('hl.dsp.window.set_prop({ window = "address:0x' + bare(address) + '", prop = "no_anim", value = "' + (on ? 1 : 0) + '" })')
  }

  Component {
    id: helperProcess
    Process {
      id: proc
      property var callback: null
      stdout: StdioCollector {
        onStreamFinished: {
          let data = null
          try { data = JSON.parse(text) } catch (e) { data = null }
          if (proc.callback) proc.callback(data)
          Qt.callLater(() => proc.destroy())
        }
      }
    }
  }

  // Runs bin/burn-window and hands its JSON (or null) to `callback`.
  function runHelper(args, callback) {
    const proc = helperProcess.createObject(root, { command: [helper].concat(args), callback: callback })
    proc.running = true
  }

  // ------------------------------------------------------------- surfaces

  Variants {
    id: surfaces
    model: Quickshell.screens

    PanelWindow {
      id: surface
      required property var modelData
      property alias stage: stage
      property int playing: 0

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "omarchy-burn"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}
      // Only mapped while something plays, so a fullscreen game keeps direct
      // scanout the rest of the time.
      visible: playing > 0

      Item { id: stage; anchors.fill: parent }
    }
  }

  function surfaceFor(monitorName) {
    const list = surfaces.instances
    for (let i = 0; i < list.length; i++)
      if (list[i].modelData && list[i].modelData.name === monitorName) return list[i]
    return list.length === 1 ? list[0] : null
  }

  Component { id: effectComponent; BurnEffect { } }

  function spawn(info, def, opening, speed) {
    const surface = surfaceFor(info.monitor)
    const toplevel = toplevelFor(info.address)
    if (!surface || !toplevel || !toplevel.wayland) return null
    const at = info.monitorAt || [0, 0]
    const tints = tintFor(def)
    const w = info.size[0], h = info.size[1]
    let origin = Qt.point(0.5, 0.5)
    if (def.followsPointer) {
      const cx = (info.cursor[0] - info.at[0]) / w, cy = (info.cursor[1] - info.at[1]) / h
      origin = (!opening && cx >= 0 && cx <= 1 && cy >= 0 && cy <= 1)
        ? Qt.point(cx, cy) : Qt.point(0.2 + Math.random() * 0.6, 0.2 + Math.random() * 0.6)
    }
    const fx = effectComponent.createObject(surface.stage, {
      toplevel: toplevel,
      address: bare(info.address),
      def: def,
      opening: opening,
      duration: Math.round(Number(def.duration || 1000) / Math.max(0.1, Number(speed) || 1)),
      intensity: Math.max(0.25, Math.min(2.5, Number(settings.intensity) || 1)),
      tint: tints[0],
      tint2: tints[1],
      borderColor: info.border ? "#" + info.border : "transparent",
      borderSize: Number(info.borderSize) || 0,
      screenAt: Qt.point(at[0], at[1]),
      winX: info.at[0] - at[0],
      winY: info.at[1] - at[1],
      winW: w,
      winH: h,
      origin: origin
    })
    if (!fx) return null
    surface.playing++
    fx.Component.destruction.connect(() => { surface.playing = Math.max(0, surface.playing - 1) })
    return fx
  }

  function track(address, value) {
    const next = Object.assign({}, active)
    if (value) next[bare(address)] = value
    else delete next[bare(address)]
    active = next
  }

  // ------------------------------------------------------------- closing

  // Closes a window (the active one by default) with an effect. Falls back
  // to a plain close whenever an effect can't run, so the key always works.
  function closeWindow(address, effectId) {
    if (!settings.enabled || !closeSettings.enabled) return closeNow(address)
    if (address && active[bare(address)]) return
    runHelper(["info"].concat(address ? ["0x" + bare(address)] : []), info => {
      if (!info || !info.address) return closeNow(address)
      const def = effectId ? effectDef(effectId) : pickEffect(closeSettings.effects)
      if (!def || excluded(info) || !info.visible || active[bare(info.address)]) return closeNow(info.address)
      const fx = spawn(info, def, false, closeSettings.speed)
      if (!fx) return closeNow(info.address)
      track(info.address, fx)
      const addr = bare(info.address)
      let closed = false
      const giveUp = timerComponent.createObject(fx, { interval: 900 })
      fx.captureReady.connect(() => {
        // The copy now covers the window, so it can vanish without a trace.
        setNoAnim(addr, true)
        closeNow(addr)
        giveUp.start()
      })
      giveUp.triggered.connect(() => {
        // Still there: the app asked something (unsaved work) or refused.
        if (closed) return
        setNoAnim(addr, false)
        track(addr, null)
        fx.destroy()
      })
      fx.closedSignal = () => { closed = true; giveUp.stop(); fx.play() }
      fx.finished.connect(() => { track(addr, null); fx.destroy() })
      noContent(fx, () => { track(addr, null); fx.destroy(); closeNow(addr) })
    })
  }

  Component { id: timerComponent; Timer { } }

  // If the capture never arrives, `fallback` runs instead.
  function noContent(fx, fallback) {
    const t = timerComponent.createObject(fx, { interval: 700 })
    t.triggered.connect(() => { if (!fx.captured) fallback() })
    t.start()
  }

  // ------------------------------------------------------------- opening

  function openWindow(address, cls) {
    if (!settings.enabled || !openSettings.enabled) return
    if ((settings.exclude || []).indexOf(cls) !== -1) return
    const addr = bare(address)
    if (active[addr]) return
    const def = pickEffect(openSettings.effects)
    if (!def) return
    track(addr, true)
    runHelper(["hide", "0x" + addr], info => {
      if (!info || !info.address || excluded(info) || !info.visible) return restore(addr)
      waitForToplevel(addr, 12, () => {
        const fx = spawn(info, def, true, openSettings.speed)
        if (!fx) return restore(addr)
        track(addr, fx)
        fx.captureReady.connect(() => fx.play())
        fx.finished.connect(() => restore(addr, fx))
        noContent(fx, () => restore(addr, fx))
      })
    })
  }

  // Hyprland announces the window before Quickshell has its toplevel.
  function waitForToplevel(addr, tries, then) {
    const top = toplevelFor(addr)
    if ((top && top.wayland) || tries <= 0) return then()
    Hyprland.refreshToplevels()
    const t = timerComponent.createObject(root, { interval: 25 })
    t.triggered.connect(() => { t.destroy(); waitForToplevel(addr, tries - 1, then) })
    t.start()
  }

  // Shows the real window again, then drops the copy a moment later so
  // there is never a frame with neither.
  function restore(addr, fx) {
    runHelper(["show", "0x" + addr], () => {
      if (fx) {
        const t = timerComponent.createObject(fx, { interval: 60 })
        t.triggered.connect(() => fx.destroy())
        t.start()
      }
      track(addr, null)
    })
  }

  // An opening window settles into its tile while the effect plays, so the
  // copy follows it.
  Timer {
    interval: 50
    repeat: true
    running: Object.keys(root.active).some(k => root.active[k] && root.active[k].opening)
    onTriggered: {
      Hyprland.refreshToplevels()
      for (const key in root.active) {
        const fx = root.active[key]
        if (!fx || !fx.opening || !fx.toplevel) continue
        const ipc = fx.toplevel.lastIpcObject || {}
        if (!ipc.at || !ipc.size) continue
        fx.winX = ipc.at[0] - fx.screenAt.x
        fx.winY = ipc.at[1] - fx.screenAt.y
        fx.winW = ipc.size[0]
        fx.winH = ipc.size[1]
      }
    }
  }

  // ------------------------------------------------------------- preview

  // Plays an effect on the active window without closing it: out, then back.
  function preview(effectId, direction) {
    const def = effectId ? effectDef(effectId) : pickEffect(closeSettings.effects)
    if (!def) return
    runHelper(["info"], first => {
      if (!first || !first.address || active[bare(first.address)]) return
      const addr = bare(first.address)
      track(addr, true)
      runHelper(["hide", "0x" + addr], info => {
        if (!info || !info.address) return restore(addr)
        const fx = spawn(info, def, direction === "open", closeSettings.speed)
        if (!fx) return restore(addr)
        fx.live = true
        track(addr, fx)
        fx.captureReady.connect(() => fx.play())
        fx.finished.connect(() => {
          if (direction === "both" && !fx.opening) {
            fx.opening = true
            fx.play()
          } else {
            restore(addr, fx)
          }
        })
        noContent(fx, () => restore(addr, fx))
      })
    })
  }

  // ------------------------------------------------------------- events

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "openwindow") {
        const parts = String(event.data).split(",")
        root.openWindow(parts[0], parts[2] || "")
      } else if (event.name === "closewindow") {
        const fx = root.active[root.bare(event.data)]
        if (fx && fx.closedSignal) fx.closedSignal()
      }
    }
  }

  // A shell restart in the middle of an effect would leave a window hidden.
  Component.onCompleted: runHelper(["rescue"], () => {})

  IpcHandler {
    target: "burn"

    function close(): void { root.closeWindow("", "") }
    function closeAddress(address: string): void { root.closeWindow(address, "") }
    function closeWith(effect: string): void { root.closeWindow("", effect) }
    function preview(effect: string): void { root.preview(effect, "both") }
    function previewOpen(effect: string): void { root.preview(effect, "open") }
    function previewClose(effect: string): void { root.preview(effect, "close") }
    function effects(): string { return JSON.stringify(root.catalog.map(e => e.id)) }
    function status(): string {
      return JSON.stringify({ settings: root.settings, playing: Object.keys(root.active).length })
    }
    function rescue(): void { root.runHelper(["rescue"], () => {}) }
  }
}

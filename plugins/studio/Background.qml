import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Studio's desktop background (from Hyprskin). A drop-in replacement for
// omarchy.background that keeps the same "background" IPC contract, so
// `omarchy theme set` and `omarchy theme bg set` keep working. The manifest's
// clonedFrom slot is taken by omarchy.menu, so install.sh lists
// omarchy.background in disabledPlugins itself. On top of the stock renderer:
//
//   - selectable transitions, duration, easing, direction and origin
//   - fill styles: crop, fit, stretch, center, tile
//   - the auto-change timer that calls `hyprskin next`
//
// Settings come from ~/.config/omarchy/hyprskin.json and apply live.
Item {
  id: root

  property var shell: null
  readonly property string home: Quickshell.env("HOME")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"
  readonly property string settingsPath: configHome + "/omarchy/hyprskin.json"
  readonly property string statePath: stateHome + "/hyprskin/state.json"
  readonly property string script: decodeURIComponent(Qt.resolvedUrl("bin/hyprskin").toString().replace(/^file:\/\//, ""))

  // ------------------------------------------------------------- settings

  property var settings: ({})
  readonly property var transitionSettings: settings.transition || {}
  readonly property var transitionTypes: [
    "fade", "slant", "wipe", "grow", "outer", "blinds", "slide", "push", "zoom", "blur"
  ]
  readonly property string configuredTransition: String(transitionSettings.type || "grow")
  readonly property int transitionDuration: Math.max(0, Number(transitionSettings.duration) || 900)
  readonly property string easingName: String(transitionSettings.easing || "InOutCubic")
  readonly property string direction: String(transitionSettings.direction || "left")
  readonly property string origin: String(transitionSettings.position || "center")
  readonly property string fillName: String(settings.fill || "crop")
  readonly property color fillColor: settings.fillColor ? settings.fillColor : Commons.Color.background
  readonly property int rotationMinutes: Math.max(0, Number((settings.rotation || {}).interval) || 0)

  // The transition the running reveal uses; "random" is resolved per change.
  property string activeTransition: "grow"
  property string activeDirection: "left"
  property real originX: 0.5
  property real originY: 0.5

  readonly property bool usesMask: ["slant", "wipe", "grow", "outer", "blinds"].indexOf(activeTransition) !== -1
  readonly property bool movesOld: activeTransition === "push" || activeTransition === "zoom"

  function fillMode(name) {
    switch (name) {
    case "fit": return Image.PreserveAspectFit
    case "stretch": return Image.Stretch
    case "center": return Image.Pad
    case "tile": return Image.Tile
    default: return Image.PreserveAspectCrop
    }
  }

  function easingType(name) {
    var map = {
      "Linear": Easing.Linear, "InOutQuad": Easing.InOutQuad, "InOutCubic": Easing.InOutCubic,
      "OutCubic": Easing.OutCubic, "OutQuint": Easing.OutQuint, "OutExpo": Easing.OutExpo,
      "InOutExpo": Easing.InOutExpo, "OutBack": Easing.OutBack, "OutBounce": Easing.OutBounce,
      "InOutSine": Easing.InOutSine
    }
    return map[name] !== undefined ? map[name] : Easing.InOutCubic
  }

  function originPoint(name) {
    var points = {
      "center": [0.5, 0.5], "top-left": [0, 0], "top-right": [1, 0],
      "bottom-left": [0, 1], "bottom-right": [1, 1], "top": [0.5, 0], "bottom": [0.5, 1]
    }
    if (name === "random") return [Math.random(), Math.random()]
    return points[name] || points.center
  }

  function pickTransition() {
    var type = configuredTransition
    if (type === "random") type = transitionTypes[Math.floor(Math.random() * transitionTypes.length)]
    if (type !== "none" && transitionTypes.indexOf(type) === -1) type = "grow"
    activeTransition = type
    var dirs = ["left", "right", "up", "down"]
    activeDirection = direction === "random" ? dirs[Math.floor(Math.random() * dirs.length)] : direction
    var p = originPoint(origin)
    originX = p[0]
    originY = p[1]
  }

  FileView {
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.settings = JSON.parse(text()) || {} } catch (e) { }
    }
    onLoadFailed: root.settings = ({})
  }

  // ------------------------------------------------------------- rotation

  property int lastChangedAt: 0
  property real retryAfter: 0
  readonly property real startedAt: Date.now()

  FileView {
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.lastChangedAt = Number(JSON.parse(text()).lastChangedAt) || 0 } catch (e) { }
    }
  }

  function rotateNow() {
    if (rotateProc.running) return
    rotateProc.running = true
  }

  Timer {
    interval: 15000
    repeat: true
    running: root.rotationMinutes > 0
    triggeredOnStart: false
    onTriggered: {
      var now = Date.now()
      if (now < root.retryAfter) return
      var since = Math.max(root.lastChangedAt * 1000, root.startedAt)
      if (now - since >= root.rotationMinutes * 60000) root.rotateNow()
    }
  }

  Process {
    id: rotateProc
    command: ["python3", root.script, "next", "--auto"]
    stderr: StdioCollector { id: rotateErr }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        // Offline or rate-limited: try again in five minutes, not every tick.
        root.retryAfter = Date.now() + 5 * 60000
        console.warn("hyprskin rotation failed: " + String(rotateErr.text || "").trim())
      }
    }
  }

  ShellIpc {
    target: "hyprskin"

    function next(): void { root.rotateNow() }
    function reload(): void { root.refreshBackground() }
    // What this renderer is showing, for checking it from a terminal.
    function current(): string { return root.currentBackground }
  }

  // ------------------------------------------------- stock renderer guard
  //
  // omarchy.background and this service both answer the "background" IPC
  // target, and the shell gives it to whichever registered first. If the stock
  // plugin is enabled (an Omarchy update or `omarchy refresh shell` can drop
  // it from disabledPlugins), it takes `background set`, so the theme switches
  // but this renderer's picture never does. Turn it back off when seen.
  Process {
    id: guardProc
    command: ["bash", "-c",
      "omarchy-shell shell listPlugins | python3 -c 'import json,sys; sys.exit(0 if any(p[\"id\"]==\"omarchy.background\" and p[\"enabled\"] for p in json.load(sys.stdin)) else 1)'"
      + " && omarchy-shell shell setPluginEnabled omarchy.background false && echo disabled"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text || "").indexOf("disabled") === -1) return
        console.warn("omacraft.studio: omarchy.background was enabled and was hiding wallpaper changes; disabled it")
        root.refreshBackground()
      }
    }
  }

  // Shortly after start, then now and then: re-enabling it takes no restart.
  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: {
      interval = 90000
      if (!guardProc.running) guardProc.running = true
    }
  }

  // The symlink is the source of truth; follow it even when an IPC call went
  // elsewhere. setBackground ignores the path already shown.
  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: {
      if (root.transitioning || root.incomingBackground !== "" || readlinkProc.running) return
      readlinkProc.fromPoll = true
      root.refreshBackground()
    }
  }

  // ---------------------------------------------------- background state
  //
  // Below mirrors omarchy.background so theme switches behave the same:
  // prepared frames, snapshot paths, pending theme payloads applied as the
  // reveal starts.

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  property string preparedBackground: ""
  property string lastTransitionPath: ""
  property var nativeSizes: ({})
  property var sizeQueue: []
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1

  readonly property bool transitioning: incomingBackground !== "" && revealProgress < 1

  function isVideo(path) {
    return Util.isVideoPath(path)
  }

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function setBackground(path, instant) {
    transitionBackground("", path, path, instant, false)
  }

  function transitionBackground(fromPath, path, finalPath, instant, force) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    if (path !== preparedBackground) preparedBackground = ""
    preparedBackgroundTimer.stop()
    lastTransitionPath = path
    requestNativeSize(path)
    requestNativeSize(fromPath || displayedBackground)
    requestNativeSize(finalPath)
    currentBackground = finalPath
    backgroundVersion += 1
    revealStartedVersion = -1

    revealAnimation.stop()
    finishingTransition = false
    pickTransition()

    if (instant || activeTransition === "none" || transitionDuration === 0 || !displayedBackground
        || isVideo(path) || isVideo(displayedBackground)) {
      oldBackground = ""
      incomingBackground = ""
      preparedBackground = ""
      displayedBackground = finalPath
      revealProgress = 1
      return
    }

    oldBackground = fromPath || displayedBackground
    incomingBackground = path
    revealProgress = 0
  }

  function setPendingTheme(colorsB64, shellB64) {
    pendingColorsRaw = Util.decodeBase64(colorsB64)
    pendingShellRaw = Util.decodeBase64(shellB64)
    pendingThemeVersion = backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    if (pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Commons.Color.loadColors(pendingColorsRaw)
    Commons.Color.loadShell(pendingShellRaw)
    Style.scheduleRefresh()
    pendingThemeVersion = -1
    pendingColorsRaw = ""
    pendingShellRaw = ""
  }

  function transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    transitionBackground(fromPath, path, finalPath, false, true)
    setPendingTheme(colorsB64, shellB64)
    if (!incomingBackground || revealProgress >= 1) applyPendingTheme()
  }

  function startReveal(panel) {
    if (!incomingBackground) return
    panel.maskReady = true
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    applyPendingTheme()
    revealAnimation.restart()
  }

  function prepareBackground(path) {
    path = String(path || "").trim()
    if (!path || isVideo(path) || path === lastTransitionPath || path === displayedBackground) return
    requestNativeSize(path)
    preparedBackground = path
    preparedBackgroundTimer.restart()
  }

  function requestNativeSize(path) {
    if (!path || isVideo(path) || nativeSizes[path] !== undefined || sizeQueue.indexOf(path) !== -1) return
    sizeQueue = sizeQueue.concat([path])
    probeNextSize()
  }

  function probeNextSize() {
    if (sizeProbe.running || sizeQueue.length === 0) return
    sizeProbe.path = sizeQueue[0]
    sizeProbe.command = ["magick", "identify", "-ping", "-format", "%w %h", sizeProbe.path + "[0]"]
    sizeProbe.running = true
  }

  function pruneNativeSizes() {
    var kept = {}
    var paths = [displayedBackground, incomingBackground, oldBackground, preparedBackground]
    for (var i = 0; i < paths.length; i++) {
      if (paths[i] && nativeSizes[paths[i]] !== undefined) kept[paths[i]] = nativeSizes[paths[i]]
    }
    nativeSizes = kept
  }

  function openSelector() {
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  // Right double-click: OmaCraft's wallpaper carousel. Without it (not
  // installed, or switched off) Omarchy's own picker opens as before.
  function openThemeSwitcher() {
    if (root.shell && root.shell.summon("omacraft.wallpicker", "{}")) return
    var payload = JSON.stringify({ source: "themes" })
    if (root.shell && root.shell.summon("omarchy.image-picker", payload)) return
    Util.execArgv(["omarchy-shell", "shell", "summon", "omacraft.wallpicker", "{}"])
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshBackground()
  }

  Process {
    id: sizeProbe
    property string path: ""
    stdout: StdioCollector { id: sizeProbeOut }
    onExited: function(exitCode) {
      var parts = String(sizeProbeOut.text || "").trim().split(/\s+/)
      var width = exitCode === 0 ? parseInt(parts[0], 10) : 0
      var height = exitCode === 0 ? parseInt(parts[1], 10) : 0
      var known = Object.assign({}, root.nativeSizes)
      known[path] = { width: width > 0 ? width : 0, height: height > 0 ? height : 0 }
      root.nativeSizes = known
      root.sizeQueue = root.sizeQueue.filter(function(queued) { return queued !== sizeProbe.path })
      root.probeNextSize()
    }
  }

  Process {
    id: readlinkProc
    property bool fromPoll: false
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: {
        var path = String(text || "").trim()
        // The poll found a change no IPC call told us about: something else
        // holds the "background" target. Check for the stock renderer.
        if (readlinkProc.fromPoll && path && path !== root.currentBackground && !guardProc.running) guardProc.running = true
        readlinkProc.fromPoll = false
        root.setBackground(path, false)
      }
    }
  }

  // ------------------------------------------------- follow the wallpaper
  //
  // A plain `background set` (the background switcher, `omarchy theme bg
  // next/set`) changes only the image. Hand it to `hyprskin follow`, which
  // rebuilds the theme and bar colours from it when wallpaper colours are on.
  // Theme switches arrive as themeTransition and are left alone. Quick
  // successive sets (browsing the switcher) settle before anything runs.
  property string followPath: ""

  function followWallpaper(path) {
    root.followPath = String(path || "")
    if (root.followPath !== "") followDelay.restart()
  }

  Timer {
    id: followDelay
    interval: 1200
    onTriggered: {
      if (followProc.running) { restart(); return }
      followProc.command = ["python3", root.script, "follow", root.followPath]
      followProc.running = true
    }
  }

  Process {
    id: followProc
    stderr: StdioCollector { id: followErr }
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("hyprskin follow failed: " + String(followErr.text || "").trim())
    }
  }

  ShellIpc {
    target: "background"

    function refresh(): void { root.refreshBackground() }
    function set(path: string): void { root.setBackground(path, false); root.followWallpaper(path) }
    function setInstant(path: string): void { root.setBackground(path, true); root.followWallpaper(path) }
    function transition(fromPath: string, path: string): void {
      root.transitionBackground(fromPath, path, path, false, false)
    }
    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }
    function prepare(path: string): void { root.prepareBackground(path) }
  }

  Timer {
    id: preparedBackgroundTimer
    interval: 5000
    repeat: false
    onTriggered: root.preparedBackground = ""
  }

  Timer {
    id: pendingThemeFallbackTimer
    // A long transition must not hold the new palette back for its whole run.
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: Style.duration(root.transitionDuration)
    easing.type: root.easingType(root.easingName)
    onFinished: {
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
      root.revealProgress = 1
    }
  }

  Component.onCompleted: refreshBackground()

  // --------------------------------------------------------------- render

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: root.fillColor
      updatesEnabled: true

      property bool maskReady: false

      readonly property bool sized: width > 0 && height > 0
      readonly property int decodeWidth: sized ? Math.ceil(width * screen.devicePixelRatio) : 0
      readonly property int decodeHeight: sized ? Math.ceil(height * screen.devicePixelRatio) : 0
      readonly property int imageFill: root.fillMode(root.fillName)
      // Center and tile show the file at its own pixel size.
      readonly property bool nativeDecode: root.fillName === "center" || root.fillName === "tile"

      function decodeSize(path) {
        if (!sized || !path) return Qt.size(0, 0)
        var native = root.nativeSizes[path]
        if (native === undefined) return Qt.size(0, 0)
        if (nativeDecode && native.width > 0) return Qt.size(native.width, native.height)
        if (native.width > 0 && (native.width < decodeWidth || native.height < decodeHeight)) return Qt.size(native.width, native.height)
        return Qt.size(decodeWidth, decodeHeight)
      }

      function maybeStartReveal() {
        if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
        if (incomingFrame.status !== Image.Ready) return
        // Moving transitions show the old frame itself, so wait for it too.
        if (root.movesOld && root.oldBackground && oldFrame.status === Image.Loading) return
        Qt.callLater(function() {
          if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
          if (incomingFrame.status !== Image.Ready) return
          root.startReveal(panel)
        })
      }

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      readonly property real p: root.revealProgress
      readonly property real dx: root.activeDirection === "left" ? -1 : (root.activeDirection === "right" ? 1 : 0)
      readonly property real dy: root.activeDirection === "up" ? -1 : (root.activeDirection === "down" ? 1 : 0)

      Image {
        id: base
        anchors.fill: parent
        readonly property size decode: panel.decodeSize(root.displayedBackground)
        source: root.displayedBackground && !root.isVideo(root.displayedBackground) && decode.width > 0
          ? root.imageUrl(root.displayedBackground) : ""
        sourceSize.width: decode.width
        sourceSize.height: decode.height
        fillMode: panel.imageFill
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        // Push and zoom move the old frame, so the static copy must not show behind it.
        visible: !(root.transitioning && root.movesOld && panel.maskReady)
        onStatusChanged: {
          if (status === Image.Ready && root.finishingTransition) {
            root.incomingBackground = ""
            root.oldBackground = ""
            root.preparedBackground = ""
            root.finishingTransition = false
            root.pruneNativeSizes()
          }
        }
      }

      Image {
        id: oldFrame
        anchors.fill: parent
        readonly property size decode: panel.decodeSize(root.oldBackground)
        source: decode.width > 0 ? root.imageUrl(root.oldBackground) : ""
        sourceSize.width: decode.width
        sourceSize.height: decode.height
        fillMode: panel.imageFill
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: root.oldBackground !== "" && root.revealProgress < 1
        onStatusChanged: panel.maybeStartReveal()

        transform: [
          Translate {
            x: root.activeTransition === "push" ? panel.dx * panel.width * panel.p : 0
            y: root.activeTransition === "push" ? panel.dy * panel.height * panel.p : 0
          },
          Scale {
            origin.x: panel.width * root.originX
            origin.y: panel.height * root.originY
            readonly property real s: root.activeTransition === "zoom" && root.transitioning ? 1 + 0.08 * panel.p : 1
            xScale: s
            yScale: s
          }
        ]
        opacity: root.activeTransition === "zoom" && root.transitioning ? 1 - panel.p : 1
      }

      Item {
        id: incomingLayer
        anchors.fill: parent
        visible: root.incomingBackground !== "" && incomingFrame.status === Image.Ready && (root.revealProgress >= 1 || panel.maskReady)
        opacity: !root.transitioning ? 1
          : (["fade", "zoom", "blur"].indexOf(root.activeTransition) !== -1 ? panel.p : 1)

        readonly property bool slides: root.activeTransition === "slide" || root.activeTransition === "push"
        transform: [
          Translate {
            // Enters from the side opposite the direction of travel.
            x: incomingLayer.slides && root.transitioning ? -panel.dx * panel.width * (1 - panel.p) : 0
            y: incomingLayer.slides && root.transitioning ? -panel.dy * panel.height * (1 - panel.p) : 0
          },
          Scale {
            origin.x: panel.width * root.originX
            origin.y: panel.height * root.originY
            readonly property real s: root.activeTransition === "zoom" && root.transitioning ? 1.15 - 0.15 * panel.p : 1
            xScale: s
            yScale: s
          }
        ]

        layer.enabled: root.transitioning && (root.usesMask || root.activeTransition === "blur")
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: root.usesMask
          maskSource: revealMask
          maskInverted: root.activeTransition === "outer"
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.02
          blurEnabled: root.activeTransition === "blur"
          blurMax: 64
          autoPaddingEnabled: false
          blur: root.activeTransition === "blur" ? 1 - panel.p : 0
        }

        Image {
          id: incomingFrame
          anchors.fill: parent
          readonly property string framePath: root.incomingBackground || root.preparedBackground
          readonly property size decode: panel.decodeSize(framePath)
          source: decode.width > 0 ? root.imageUrl(framePath) : ""
          sourceSize.width: decode.width
          sourceSize.height: decode.height
          fillMode: panel.imageFill
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          onStatusChanged: panel.maybeStartReveal()
        }
      }

      // White = incoming visible. Only the shape for the active transition draws.
      Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property string kind: root.activeTransition
        readonly property real cx: width * root.originX
        readonly property real cy: height * root.originY
        // Distance from the origin to the farthest corner.
        readonly property real farthest: Math.sqrt(
          Math.pow(Math.max(cx, width - cx), 2) + Math.pow(Math.max(cy, height - cy), 2)) + 4

        // Slant: the stock Omarchy reveal.
        Shape {
          id: slantShape
          anchors.fill: parent
          visible: revealMask.kind === "slant"
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          readonly property real slant: -0.18
          readonly property real centerTop: width / 2 - slant * height / 2
          readonly property real centerBottom: width / 2 + slant * height / 2
          readonly property real spread: (width / 2 + Math.abs(slant) * height / 2 + 4) * panel.p
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: slantShape.centerTop - slantShape.spread; startY: 0
            PathLine { x: slantShape.centerTop + slantShape.spread; y: 0 }
            PathLine { x: slantShape.centerBottom + slantShape.spread; y: revealMask.height }
            PathLine { x: slantShape.centerBottom - slantShape.spread; y: revealMask.height }
            PathLine { x: slantShape.centerTop - slantShape.spread; y: 0 }
          }
        }

        // Wipe: an edge sweeping in the configured direction.
        Rectangle {
          visible: revealMask.kind === "wipe"
          color: "white"
          readonly property bool horizontal: panel.dx !== 0
          width: horizontal ? revealMask.width * panel.p : revealMask.width
          height: horizontal ? revealMask.height : revealMask.height * panel.p
          x: panel.dx < 0 ? revealMask.width - width : 0
          y: panel.dy < 0 ? revealMask.height - height : 0
        }

        // Grow / outer: a circle from the origin (outer inverts the mask).
        Rectangle {
          visible: revealMask.kind === "grow" || revealMask.kind === "outer"
          color: "white"
          readonly property real r: revealMask.farthest * (revealMask.kind === "outer" ? 1 - panel.p : panel.p)
          width: r * 2
          height: r * 2
          radius: r
          x: revealMask.cx - r
          y: revealMask.cy - r
          antialiasing: true
        }

        // Blinds: horizontal or vertical slats opening together.
        Repeater {
          model: revealMask.kind === "blinds" ? 14 : 0
          Rectangle {
            required property int index
            color: "white"
            readonly property bool vertical: panel.dx !== 0
            readonly property real slat: (vertical ? revealMask.width : revealMask.height) / 14
            x: vertical ? index * slat : 0
            y: vertical ? 0 : index * slat
            width: vertical ? Math.ceil(slat * panel.p) + 1 : revealMask.width
            height: vertical ? revealMask.height : Math.ceil(slat * panel.p) + 1
          }
        }
      }

      Connections {
        target: root
        function onIncomingBackgroundChanged() {
          panel.maskReady = false
          panel.maybeStartReveal()
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
          else root.openSelector()
          mouse.accepted = true
        }
      }
    }
  }
}

import Quickshell
import Quickshell.Wayland
import QtQuick

// One effect playing over one window. It covers the window plus some padding,
// draws a copy of the window through ScreencopyView, and runs the effect's
// shader over that copy while the real window is hidden (opening) or already
// gone (closing).
Item {
  id: fx

  property var toplevel: null
  property string address: ""
  property var def: ({})
  property bool opening: false
  // Opening windows keep drawing while they appear; a closing one is frozen
  // on its last frame, since it will be gone a moment later.
  property bool live: opening
  property int duration: 1000
  property real intensity: 1
  property color tint: "white"
  property color tint2: "white"
  property color borderColor: "transparent"
  property real borderSize: 0
  // Where this screen sits in Hyprland's layout.
  property point screenAt: Qt.point(0, 0)
  // Called by Burn.qml when Hyprland reports the window closed.
  property var closedSignal: null
  // The window, in this screen's coordinates.
  property real winX: 0
  property real winY: 0
  property real winW: 1
  property real winH: 1
  // Where effects that start from a point start, in window uv.
  property point origin: Qt.point(0.5, 0.5)

  readonly property real padPx: Math.ceil((Number(def.pad) || 0) * Math.max(winW, winH) + borderSize + 1)
  property real progress: opening ? 1 : 0
  property real time: 0
  readonly property real seed: Math.random()
  property bool captured: false
  readonly property bool playing: anim.running

  signal captureReady()
  signal finished()

  x: winX - padPx
  y: winY - padPx
  width: winW + 2 * padPx
  height: winH + 2 * padPx

  // Plays from the current end to the other. `opening` decides the direction.
  function play() {
    anim.stop()
    anim.from = opening ? 1 : 0
    anim.to = opening ? 0 : 1
    progress = anim.from
    anim.duration = Math.max(80, duration)
    anim.start()
  }

  ScreencopyView {
    id: capture
    x: fx.padPx
    y: fx.padPx
    width: fx.winW
    height: fx.winH
    captureSource: fx.toplevel ? fx.toplevel.wayland : null
    live: fx.live
    onHasContentChanged: if (hasContent && !fx.captured) settle.restart()
  }

  ShaderEffectSource {
    id: snapshot
    sourceItem: capture
    hideSource: true
    live: fx.live
    visible: false
  }

  // Give the frozen copy a frame or two to land before anyone relies on it.
  Timer {
    id: settle
    interval: 34
    onTriggered: {
      if (!fx.live) snapshot.scheduleUpdate()
      readyTimer.restart()
    }
  }
  Timer {
    id: readyTimer
    interval: 34
    onTriggered: {
      fx.captured = true
      fx.captureReady()
    }
  }

  ShaderEffect {
    id: shader
    anchors.fill: parent
    visible: fx.captured
    fragmentShader: fx.def.id ? Qt.resolvedUrl("shaders/" + fx.def.id + ".frag.qsb") : ""

    property var source: snapshot
    property real progress: fx.progress
    property real time: fx.time
    property real seed: fx.seed
    property real opening: fx.opening ? 1 : 0
    property real intensity: fx.intensity
    property real border: fx.borderSize
    property point size: Qt.point(width, height)
    property point pad: Qt.point(fx.padPx, fx.padPx)
    property point origin: fx.origin
    property color color: fx.tint
    property color color2: fx.tint2
    property color borderColor: fx.borderColor
  }

  NumberAnimation {
    id: anim
    target: fx
    property: "progress"
    easing.type: Easing.Linear
    onFinished: fx.finished()
  }

  FrameAnimation {
    running: fx.captured && fx.visible
    onTriggered: fx.time += frameTime
  }
}

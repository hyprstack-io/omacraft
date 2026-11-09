import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "CarouselModel.js" as Model

// HyprVYZR's carousel: every Kasm workspace you can start, as the wallpaper
// picker's slanted slices (this is that picker's code, with workspaces in
// place of wallpapers), in tabs: everything, the remote servers, the server
// on this machine, native images run straight in Docker, and the sessions
// already running. Enter starts the one in front in its own window, or, on
// Running, brings it back from the bar.
//
//   omarchy-shell shell toggle omacraft.hyprvyzr '{"tab":"remote"}'
//   omarchy-shell hyprvyzr toggle remote
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null
  readonly property string pluginId: (root.manifest && root.manifest.id) || "omacraft.hyprvyzr"

  readonly property string home: Quickshell.env("HOME")
  readonly property string cli: String(Qt.resolvedUrl("bin/hyprvyzr")).replace(/^file:\/\//, "")

  property bool opened: false

  readonly property var tabs: [
    { id: "all", label: "All" },
    { id: "remote", label: "Remote" },
    { id: "local", label: "Local" },
    { id: "native", label: "Native" },
    { id: "running", label: "Running" }
  ]
  property string tab: "all"
  readonly property int tabIndex: tabIds().indexOf(tab)

  property var workspaces: []
  property var sessions: []
  property var errors: []
  readonly property var workspaceList: Model.workspaceEntries(workspaces)
  readonly property var sessionList: Model.sessionEntries(sessions, workspaces)
  readonly property var entries: Model.forTab(tab, workspaceList, sessionList)

  property string filterText: ""
  property string error: ""
  property string starting: ""

  property int selectedIndex: 0
  property var selectedByTab: ({})

  property color dimColor: Commons.Color.background
  readonly property color accent: Commons.Color.accent
  // accent-2, the suite's rule: the accent turned 50° round the hue wheel.
  readonly property color accent2: Qt.hsla((accent.hslHue + 50 / 360) % 1, Math.max(0.35, accent.hslSaturation), accent.hslLightness, 1)
  readonly property var tabColors: Model.tabColors({ background: String(Commons.Color.background), accent: String(accent) })
  property var borderColors: []

  // How the card in front is drawn, chosen on OmaCraft's HyprVYZR page and
  // kept in ~/.config/omacraft/hyprvyzr.json, which this follows live.
  readonly property var pickerSettings: {
    try { return JSON.parse(settingsFile.text() || "{}") || {} } catch (e) { return {} }
  }
  readonly property string cardEffect: String(pickerSettings.cardEffect || "trace")
  readonly property real cardSpeed: Number(pickerSettings.cardSpeed) > 0 ? Number(pickerSettings.cardSpeed) : 1
  readonly property bool showTitle: pickerSettings.showTitle !== false

  FileView {
    id: settingsFile
    path: root.home + "/.config/omacraft/hyprvyzr.json"
    watchChanges: true
    onFileChanged: reload()
  }
  readonly property color traceColor1: borderColors[0] || accent
  readonly property color traceColor2: borderColors[1] || accent2
  property color foreground: Commons.Color.imagePicker.text
  property color selectedBorder: Commons.Color.imagePicker.selectedBorder
  property color unselectedBorder: Commons.Color.imagePicker.unselectedBorder
  property int expandedWidth: 768
  property int expandedHeight: 475
  property int sliceWidth: 108
  property int sliceHeight: 432
  property int sliceSpacing: -30
  property int skewOffset: 28
  readonly property int titleHeight: showTitle ? 80 : 0
  readonly property int topChromeHeight: titleHeight + Style.space(64)
  readonly property int bottomChromeHeight: 116
  readonly property int previewRadius: Math.max(1, Math.min(16, Math.ceil((panel.width - expandedWidth) / (2 * (sliceWidth + sliceSpacing))) + 1))
  onPreviewRadiusChanged: updateVisibleItems()

  function tabIds() {
    return tabs.map(function(t) { return t.id })
  }

  function countFor(id) {
    return id === "running" ? sessionList.length : Model.forTab(id, workspaceList, sessionList).length
  }

  // ---------------------------------------------------------------- opening

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

  function dismiss() {
    close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function refreshAll() {
    if (!workspacesProc.running) workspacesProc.running = true
    if (!sessionsProc.running) sessionsProc.running = true
    if (!borderProc.running) borderProc.running = true
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
    restoreSelection()
    updateVisibleItems()
  }

  function restoreSelection() {
    var index = selectedByTab[tab]
    if (index === undefined || index >= entries.length) index = 0
    selectedIndex = Math.max(0, Math.min(index, entries.length - 1))
  }

  onEntriesChanged: {
    if (selectedIndex >= entries.length) selectedIndex = Math.max(0, entries.length - 1)
    visibleEntries.clear()
    updateVisibleItems()
  }

  // --------------------------------------------------------------- browsing

  readonly property var matchingIndices: Model.matchingIndices(entries, filterText)
  onMatchingIndicesChanged: {
    if (matchingIndices.length > 0 && matchingIndices.indexOf(selectedIndex) < 0) selectedIndex = matchingIndices[0]
    updateVisibleItems()
  }
  onSelectedIndexChanged: updateVisibleItems()

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
    var next = (position + direction + matchingIndices.length) % matchingIndices.length
    selectedIndex = matchingIndices[next]
  }

  // ---------------------------------------------------------------- actions

  function run(args) {
    Quickshell.execDetached(["python3", root.cli].concat(args))
  }

  // tile: start it (or bring it back) tiled into the layout instead of as a popup.
  function activate(tile) {
    var entry = currentEntry()
    if (!entry) return
    if (entry.session) {
      dismiss()
      run([tile ? "tile" : "show", entry.session.id])
      return
    }
    dismiss()
    root.starting = entry.label
    launchProc.label = entry.label
    launchProc.tile = tile
    launchProc.command = ["python3", root.cli, "--json", "launch", entry.key]
    launchProc.running = true
  }

  function endSelected() {
    var entry = currentEntry()
    if (!entry || !entry.session) return
    run(["end", entry.session.id])
    var id = entry.session.id
    sessions = sessions.filter(function(s) { return s.id !== id })
  }

  function emptyText() {
    if (error) return error
    if (entries.length > 0 && matchingIndices.length === 0) return Commons.I18n.t("common.noMatches")
    if (workspacesProc.running && workspaces.length === 0) return "Asking your servers for their workspaces…"
    if (tab === "running") return "Nothing running. Start a workspace from another tab."
    if (tab === "remote") return errors.length ? errors[0] : "No remote server yet. Add one in OmaCraft › HyprVYZR."
    if (tab === "local") return "No Kasm server on this machine. OmaCraft › HyprVYZR can install one."
    if (tab === "native") return "Native workspaces are off. Switch them on in OmaCraft › HyprVYZR."
    return "No workspaces yet. Add a server in OmaCraft › HyprVYZR, or turn on native workspaces."
  }

  function detailText() {
    var entry = currentEntry()
    if (!entry) return ""
    var bits = [entry.detail]
    if (entry.description && entry.description !== entry.label) bits.push(entry.description)
    if (matchingIndices.length > 1) bits.push((matchingIndices.indexOf(selectedIndex) + 1) + " of " + matchingIndices.length)
    return bits.join("  ·  ")
  }

  function hintText() {
    if (tab === "running")
      return "type to filter  ·  ↑ ↓ tabs  ·  Enter bring back  ·  Shift Enter tile  ·  Ctrl X end  ·  Esc close"
    return "type to filter  ·  ↑ ↓ tabs  ·  Enter start as a popup  ·  Shift Enter start tiled  ·  Ctrl R refresh  ·  Esc close"
  }

  // --------------------------------------------------------------- processes

  Process {
    id: workspacesProc
    property bool refresh: false
    command: ["python3", root.cli, "--json", "workspaces"].concat(refresh ? ["--refresh"] : [])
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text) || {}
          root.workspaces = data.workspaces || []
          root.errors = data.errors || []
        } catch (e) {
          root.error = "HyprVYZR's command didn't answer. Reinstall the plugin from OmaCraft."
        }
        workspacesProc.refresh = false
      }
    }
  }

  Process {
    id: sessionsProc
    command: ["python3", root.cli, "--json", "sessions"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.sessions = JSON.parse(text) || [] } catch (e) { root.sessions = [] }
      }
    }
  }

  // Runs on after the carousel has closed: starts the session and opens its
  // window. Errors come back as a notification from the command itself.
  Process {
    id: launchProc
    property string label: ""
    property bool tile: false
    stdout: StdioCollector { id: launchOut; waitForEnd: true }
    stderr: StdioCollector { id: launchErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.starting = ""
      if (exitCode !== 0) {
        var msg = String(launchErr.text || "").trim().split("\n").pop().replace(/^hyprvyzr:\s*/, "")
        Quickshell.execDetached(["notify-send", "-a", "HyprVYZR", "-u", "critical", "Couldn't start " + label, msg])
        return
      }
      try {
        var s = JSON.parse(launchOut.text)
        if (tile && s.id) root.run(["tile", s.id])
      } catch (e) {}
      if (!sessionsProc.running) sessionsProc.running = true
    }
  }

  Process {
    id: borderProc
    command: ["hyprctl", "getoption", "general:col.active_border", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.borderColors = Model.borderColors(text)
    }
  }

  // ---------------------------------------------------------------- surface

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omacraft-hyprvyzr"

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

      // ------------------------------------------------------------ title

      HyprvyzrTitle {
        visible: root.showTitle
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 112 * 4)
        height: root.titleHeight - Style.space(8)
        maxCell: 4
        running: root.opened
        ink: root.foreground
        accent: root.traceColor1
        accent2: root.traceColor2
      }

      // ------------------------------------------------------------ tabs

      Row {
        id: tabRow
        anchors.top: parent.top
        anchors.topMargin: root.titleHeight
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(10)

        Repeater {
          model: root.tabs

          delegate: Item {
            id: tabItem
            required property var modelData
            required property int index
            readonly property bool active: root.tab === modelData.id
            readonly property int count: root.countFor(modelData.id)
            readonly property real skew: 10

            width: tabLabel.implicitWidth + Style.space(36)
            height: Style.space(36)

            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: Util.alpha(root.tabColors.fill, tabItem.active ? 1 : (tabMouse.containsMouse ? 0.95 : 0.85))
                strokeColor: tabItem.active ? root.tabColors.text : "transparent"
                strokeWidth: 2
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
              color: root.tabColors.text
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
            if (root.filterText) root.filterText = ""
            else root.dismiss()
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activate(shift)
          } else if (ctrl && event.key === Qt.Key_X) {
            root.endSelected()
          } else if (ctrl && event.key === Qt.Key_R) {
            workspacesProc.refresh = true
            root.refreshAll()
          } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
            root.switchTab(event.key - Qt.Key_1)
          } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && shift)))) {
            root.switchTab(root.tabIndex - 1)
          } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_Tab)) {
            root.switchTab(root.tabIndex + 1)
          } else if (Util.editsFilter(event, root.filterText)) {
            root.filterText = Util.editedFilter(event, root.filterText)
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
            root.filterText = root.filterText + event.text
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
          visible: root.matchingIndices.length === 0
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
            readonly property bool selected: entryIndex === root.selectedIndex
            readonly property string thumb: entry ? String(entry.thumb || "") : ""
            // Each workspace gets its own tint, from its name, between the two accents.
            readonly property real hueShift: {
              var s = entry ? String(entry.key) : ""
              var h = 0
              for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 997
              return h / 997
            }
            readonly property color tint: Qt.hsla((root.accent.hslHue + hueShift * 50 / 360) % 1,
                                                  Math.max(0.35, root.accent.hslSaturation), 0.5, 1)

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

              // The card: a remote screen, the workspace's tint glowing from
              // behind its icon over a faint pixel grid.
              Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                  orientation: Gradient.Vertical
                  GradientStop { position: 0; color: Qt.darker(item.tint, 2.6) }
                  GradientStop { position: 1; color: Qt.darker(root.dimColor, 1.1) }
                }
              }
              Rectangle {
                anchors.centerIn: parent
                width: parent.height * 1.1
                height: width
                radius: width / 2
                opacity: item.selected ? 0.55 : 0.3
                gradient: Gradient {
                  orientation: Gradient.Vertical
                  GradientStop { position: 0; color: Util.alpha(item.tint, 0.7) }
                  GradientStop { position: 1; color: "transparent" }
                }
              }
              Canvas {
                anchors.fill: parent
                opacity: 0.12
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.strokeStyle = "rgba(255,255,255,0.6)"
                  ctx.lineWidth = 1
                  for (var x = 0; x < width; x += 24) { ctx.beginPath(); ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); ctx.stroke() }
                  for (var y = 0; y < height; y += 24) { ctx.beginPath(); ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); ctx.stroke() }
                }
              }

              Image {
                id: icon
                anchors.centerIn: parent
                anchors.verticalCenterOffset: item.selected ? -18 : 0
                width: item.selected ? 196 : 72
                height: width
                source: item.thumb ? Util.fileUrl(item.thumb) : ""
                sourceSize.width: Math.ceil(196 * Screen.devicePixelRatio)
                sourceSize.height: Math.ceil(196 * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                opacity: status === Image.Ready ? (item.entry && !item.entry.installed ? 0.55 : 1) : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
              // No picture: the workspace's glyph, or its initial.
              Text {
                visible: icon.status !== Image.Ready
                anchors.centerIn: icon
                textFormat: Text.PlainText
                text: item.entry ? (item.entry.glyph || String(item.entry.label || "?").charAt(0).toUpperCase()) : ""
                color: Qt.lighter(item.tint, 1.5)
                opacity: item.entry && !item.entry.installed ? 0.6 : 1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: item.selected ? 150 : 56
                font.weight: Font.Bold
              }

              Rectangle {
                anchors.fill: parent
                color: Util.alpha(root.dimColor, item.selected ? 0 : 0.42)
              }

              // A badge on the card in front: what it is and where it runs.
              Rectangle {
                visible: item.selected && item.entry !== undefined
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                anchors.horizontalCenter: parent.horizontalCenter
                width: badge.implicitWidth + 28
                height: 28
                color: Util.alpha(root.dimColor, 0.75)
                border.color: Util.alpha(item.tint, 0.8)
                Text {
                  id: badge
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: !item.entry ? "" : item.entry.session ? (item.entry.session.hidden ? "minimised on the bar" : "open")
                    : item.entry.kind === "native" ? String.fromCodePoint(0xF0868) + (item.entry.installed ? "  native · Docker" : "  native · downloads first")
                    : item.entry.kind === "local" ? String.fromCodePoint(0xF048B) + "  this machine" : String.fromCodePoint(0xF048D) + "  " + (item.entry.detail || "remote").replace(/^remote · /, "")
                  color: root.foreground
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: Style.font.body
                }
              }
            }

            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: "transparent"
                strokeColor: item.selected ? Util.alpha(root.selectedBorder, 0.45) : root.unselectedBorder
                strokeWidth: item.selected ? 2 : 1
                startX: item.topLeft; startY: 0
                PathLine { x: item.topRight; y: 0 }
                PathLine { x: item.bottomRight; y: item.height }
                PathLine { x: item.bottomLeft; y: item.height }
                PathLine { x: item.topLeft; y: 0 }
              }
            }

            CardBorder {
              anchors.fill: parent
              visible: item.selected
              running: item.selected && root.opened
              effect: root.cardEffect
              speed: root.cardSpeed
              topLeft: item.topLeft
              topRight: item.topRight
              bottomRight: item.bottomRight
              bottomLeft: item.bottomLeft
              color1: root.traceColor1
              color2: root.traceColor2
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (item.selected) root.activate((mouse.modifiers & Qt.ShiftModifier) !== 0)
                else root.select(item.entryIndex)
              }
            }

            // A running session's dot, on any card.
            Rectangle {
              visible: item.entry && item.entry.session !== null && item.entry.session !== undefined
              anchors.top: parent.top
              anchors.topMargin: item.selected ? 16 : 12
              anchors.right: parent.right
              anchors.rightMargin: item.selected ? 24 : 16
              width: item.selected ? 12 : 8
              height: width
              radius: width / 2
              color: item.entry && item.entry.session && item.entry.session.hidden ? root.traceColor2 : root.traceColor1
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
        text: root.starting ? "Starting " + root.starting + "…" : root.currentEntry() ? root.currentEntry().label : ""
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
        text: root.filterText ? "Filter: " + root.filterText : root.detailText()
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
        text: root.hintText()
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

  // omarchy-shell hyprvyzr open|toggle [tab], for keys and scripts.
  IpcHandler {
    target: "hyprvyzr"

    function open(tab: string): void { root.open(JSON.stringify({ tab: tab })) }
    function toggle(tab: string): void { root.open(JSON.stringify({ tab: tab, toggle: true })) }
    function close(): void { root.dismiss() }
  }
}

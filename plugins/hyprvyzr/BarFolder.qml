import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// HyprVYZR on the bar: a folder (the folder trays' drawer, from
// omacraft.folders) that slides open into your Kasm workspaces, with the
// sessions already running at its front. A session minimised from its
// window waits here: its icon carries a dot, and a click brings it back.
// The badge counts what's waiting.
//
//   click        open or fold the drawer
//   middle-click the carousel
//   right-click  every session with show, tile, float and end
//
// Settings (shell.json entry): pinned (workspace keys to show, all when
// empty), max (how many), open (click|hover), side (auto|before|after).
BarWidget {
  id: root
  moduleName: "omacraft.hyprvyzr"

  readonly property string cli: String(Qt.resolvedUrl("bin/hyprvyzr")).replace(/^file:\/\//, "")
  // nf-md-monitor_multiple
  readonly property string glyph: String.fromCodePoint(0xF0379)

  readonly property var pinned: settings && Array.isArray(settings.pinned) ? settings.pinned : []
  readonly property int maxItems: Math.max(1, Number(setting("max", 8)) || 8)
  readonly property bool openOnHover: String(setting("open", "click")) === "hover"
  readonly property string side: String(setting("side", "auto"))

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var workspaces: []
  property var sessions: []
  readonly property int waiting: sessions.filter(function(s) { return s.hidden }).length

  property bool expanded: false
  property bool menuOpen: false
  property bool opensBefore: side === "before"

  // Running sessions first, then the workspaces (pinned ones, else the first few).
  readonly property var items: {
    var out = []
    var thumbs = {}
    for (var i = 0; i < workspaces.length; i++) thumbs[workspaces[i].key] = workspaces[i]
    for (var j = 0; j < sessions.length; j++) {
      var s = sessions[j]
      var w = thumbs[s.key] || {}
      out.push({ key: "s:" + s.id, name: s.name + (s.hidden ? " (minimised)" : ""), thumb: w.thumb || "",
                 glyph: w.glyph || "", session: s })
    }
    var list = pinned.length
      ? pinned.map(function(k) { return thumbs[k] }).filter(function(w) { return !!w })
      : workspaces.filter(function(w) { return w.installed !== false })
    for (var k = 0; k < list.length && k < maxItems; k++)
      out.push({ key: list[k].key, name: list[k].name + " · " + (list[k].kind === "native" ? "native" : list[k].serverName),
                 thumb: list[k].thumb || "", glyph: list[k].glyph || "", session: null })
    return out
  }

  readonly property int slot: Style.bar.iconSlot
  readonly property int appExtent: items.length * slot
  property real progress: expanded ? 1 : 0
  readonly property real revealed: appExtent * progress

  Behavior on progress {
    NumberAnimation { duration: Style.duration(420); easing.type: Easing.OutCubic }
  }

  function run(args) {
    Quickshell.execDetached(["python3", root.cli].concat(args))
  }

  function refresh() {
    if (!sessionsProc.running) sessionsProc.running = true
  }

  function settleSide() {
    if (side !== "auto") {
      opensBefore = side === "before"
      return
    }
    var win = root.QsWindow ? root.QsWindow.window : null
    if (!win) return
    var p = root.mapToItem(null, root.width / 2, root.height / 2)
    opensBefore = root.vertical ? p.y > win.height / 2 : p.x > win.width / 2
  }

  function toggle() {
    if (!expanded) {
      settleSide()
      refresh()
      if (!workspacesProc.running) workspacesProc.running = true
    }
    expanded = !expanded
  }

  function activate(item) {
    if (item.session) run(["toggle", item.session.id])
    else run(["launch", item.key])
    expanded = false
    menuOpen = false
    sessionsSoon.restart()
  }

  function close() {
    menuOpen = false
  }

  function carousel() {
    expanded = false
    menuOpen = false
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omacraft.hyprvyzr", JSON.stringify({ tab: "all", toggle: true })])
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

  Process {
    id: workspacesProc
    command: ["python3", root.cli, "--json", "workspaces"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.workspaces = (JSON.parse(text) || {}).workspaces || [] } catch (e) { root.workspaces = [] }
      }
    }
  }

  // Sessions come and go from their own windows too; a light poll keeps the
  // badge honest (faster while the drawer or menu is open).
  Timer {
    interval: root.expanded || root.menuOpen ? 2000 : 6000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Timer { id: sessionsSoon; interval: 1500; onTriggered: root.refresh() }
  Component.onCompleted: workspacesProc.running = true

  implicitWidth: vertical ? barSize : button.width + (vertical ? 0 : revealed)
  implicitHeight: vertical ? button.height + revealed : barSize
  clip: false

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.openOnHover) return
      if (hovered && !root.expanded) root.toggle()
      else if (!hovered && root.expanded) root.expanded = false
    }
  }

  BarIconButton {
    id: button
    bar: root.bar
    x: root.vertical ? 0 : (root.opensBefore ? root.revealed : 0)
    y: root.vertical ? (root.opensBefore ? root.revealed : 0) : 0
    width: root.vertical ? root.barSize : implicitWidth
    height: root.vertical ? implicitHeight : root.barSize
    text: root.glyph
    active: root.expanded
    useActiveColor: false
    tooltipText: root.sessions.length === 0 ? "HyprVYZR: Kasm workspaces"
      : "HyprVYZR: " + root.sessions.length + " running" + (root.waiting ? ", " + root.waiting + " minimised here" : "")
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) { root.refresh(); root.menuOpen = !root.menuOpen }
      else if (mouseButton === Qt.MiddleButton) root.carousel()
      else if (!root.openOnHover || !root.expanded) root.toggle()
      else root.expanded = false
    }

    // The badge: sessions minimised to the bar.
    Rectangle {
      visible: root.waiting > 0
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(2)
      anchors.topMargin: Style.space(3)
      width: Math.max(height, badgeText.implicitWidth + Style.space(6))
      height: Style.space(13)
      radius: height / 2
      color: Commons.Color.accent
      Text {
        id: badgeText
        anchors.centerIn: parent
        text: root.waiting
        color: Commons.Color.background
        font.family: root.fontFamily
        font.pixelSize: Style.space(9)
        font.bold: true
      }
    }
  }

  Item {
    id: drawer
    x: root.vertical ? 0 : (root.opensBefore ? 0 : button.width)
    y: root.vertical ? (root.opensBefore ? 0 : button.height) : 0
    width: root.vertical ? root.barSize : root.revealed
    height: root.vertical ? root.revealed : root.barSize
    clip: true
    visible: root.revealed > 0.5

    Grid {
      x: root.vertical ? 0 : (root.opensBefore ? drawer.width - width : 0)
      y: root.vertical ? (root.opensBefore ? drawer.height - height : 0) : 0
      rows: root.vertical ? -1 : 1
      columns: root.vertical ? 1 : -1
      opacity: root.progress

      Repeater {
        model: root.items
        delegate: Item {
          id: app
          required property var modelData
          width: root.vertical ? root.barSize : root.slot
          height: root.vertical ? root.slot : root.barSize

          Rectangle {
            anchors.centerIn: parent
            width: root.slot - Style.space(4)
            height: width
            radius: Style.space(5)
            color: root.foreground
            opacity: appMouse.containsMouse ? 0.14 : 0
            Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
          }
          Image {
            id: appIcon
            anchors.centerIn: parent
            width: Style.bar.iconCanvas + Style.space(2)
            height: width
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
            source: app.modelData.thumb ? "file://" + app.modelData.thumb : ""
            opacity: app.modelData.session && app.modelData.session.hidden ? 0.6 : 1
            scale: appMouse.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: Style.duration(90) } }
          }
          Text {
            visible: appIcon.status !== Image.Ready
            anchors.centerIn: parent
            text: app.modelData.glyph || String(app.modelData.name || "?").charAt(0)
            color: root.foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Style.bar.iconCanvas
          }
          // Running: a dot under it, in the accent while it's open.
          Rectangle {
            visible: app.modelData.session !== null
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(2)
            width: Style.space(4)
            height: width
            radius: width / 2
            color: app.modelData.session && !app.modelData.session.hidden ? Commons.Color.accent : root.foreground
          }
          MouseArea {
            id: appMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(app.modelData)
          }
          PanelToolTip {
            visible: appMouse.containsMouse
            text: app.modelData.session ? app.modelData.name + (app.modelData.session.hidden ? ": click to bring back" : ": click to minimise") : "Start " + app.modelData.name
          }
        }
      }
    }
  }

  // Right-click: each session and what can be done with it.
  PopupCard {
    id: menu
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.menuOpen
    contentWidth: menu.fittedContentWidth(Style.space(300))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

    component MenuButton: Rectangle {
      id: mb
      property string label
      signal clicked()
      width: menuColumn.width
      height: Style.space(30)
      radius: Style.space(5)
      color: mbMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : "transparent"
      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: mb.label
        color: Commons.Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      MouseArea { id: mbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mb.clicked() }
    }

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: Style.space(2)

      Text {
        text: "HyprVYZR"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        bottomPadding: Style.space(6)
      }

      Repeater {
        model: root.sessions
        delegate: Column {
          id: sRow
          required property var modelData
          width: menuColumn.width
          spacing: Style.space(2)
          Text {
            width: parent.width
            text: sRow.modelData.name + "  ·  " + sRow.modelData.serverName + (sRow.modelData.hidden ? "  ·  minimised" : "")
            color: root.foreground
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            topPadding: Style.space(4)
          }
          Row {
            spacing: Style.space(4)
            Repeater {
              model: [
                { a: sRow.modelData.hidden ? "show" : "hide", l: sRow.modelData.hidden ? "Bring back" : "Minimise" },
                { a: sRow.modelData.floating ? "tile" : "float", l: sRow.modelData.floating ? "Tile" : "Popup" },
                { a: "end", l: "End" }
              ]
              delegate: Rectangle {
                id: chip
                required property var modelData
                width: chipText.implicitWidth + Style.space(16)
                height: Style.space(24)
                radius: Style.space(4)
                color: chipMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14) : "transparent"
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
                Text {
                  id: chipText
                  anchors.centerIn: parent
                  text: chip.modelData.l
                  color: chip.modelData.a === "end" ? Commons.Color.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                  id: chipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.run([chip.modelData.a, sRow.modelData.id]); sessionsSoon.restart() }
                }
              }
            }
          }
        }
      }

      Text {
        visible: root.sessions.length === 0
        text: "Nothing running."
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        bottomPadding: Style.space(6)
      }

      MenuButton { label: "Open the carousel"; onClicked: root.carousel() }
      MenuButton {
        label: "HyprVYZR settings in OmaCraft"
        onClicked: { root.menuOpen = false; Quickshell.execDetached(["omacraft", "hyprvyzr"]) }
      }
    }
  }
}

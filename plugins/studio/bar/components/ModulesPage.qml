import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../data/Presets.js" as P

// Drag modules between the left / center / right lanes, in from the tray, or
// drop them on the tray to remove them.
Item {
  id: page

  property var ctl

  property bool dragging: false
  property string dragId: ""
  property string dragLane: ""
  property int dragIndex: -1
  property string hoverLane: ""
  property int hoverIndex: -1
  property string query: ""
  readonly property var filteredModules: {
    var q = query.trim().toLowerCase(), src = ctl.availableModules, out = []
    for (var i = 0; i < src.length; i++) {
      var hay = (ctl.moduleLabel(src[i].id) + " " + src[i].id + " " + categoryOf(src[i])).toLowerCase()
      if (q === "" || hay.indexOf(q) !== -1) out.push(src[i])
    }
    return out
  }

  function beginDrag(chip, id, lane, index, x, y) {
    dragId = id
    dragLane = lane
    dragIndex = index
    ghostLabel.text = P.glyphFor(id) + "  " + ctl.moduleLabel(id)
    dragging = true
    moveGhost(chip, x, y)
  }

  function moveGhost(chip, x, y) {
    var p = chip.mapToItem(page, x, y)
    ghost.x = p.x - ghost.width / 2
    ghost.y = p.y - ghost.height / 2
  }

  function endDrag() {
    if (!dragging) return
    ghost.Drag.drop()
    dragging = false
    hoverLane = ""
    hoverIndex = -1
  }

  function finishDrop(lane, index) {
    if (!dragging) return
    ctl.placeEntry(dragLane, dragIndex, dragId, lane, index)
  }

  function categoryOf(entry) {
    return entry.barWidget && entry.barWidget.category ? entry.barWidget.category : ""
  }

  component Lane: Rectangle {
    id: lane

    property string name: ""
    property string title: ""
    readonly property var entries: P.laneOf(page.ctl.cfg, name)
    // ModuleChip has its own `lane` and `name` properties, which shadow this
    // item's inside the chip's bindings; the chips read these instead.
    readonly property string laneId: name
    readonly property var laneEntries: entries

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(92, flow.implicitHeight + 50)
    color: page.hoverLane === name ? Util.alpha(Commons.Color.accent, 0.1) : "transparent"
    border.width: 1
    border.color: page.hoverLane === name ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.45)

    function insertIndex(px, py) {
      var n = rep.count
      if (n === 0) return 0
      var best = 0, bestD = 1e9, after = false
      for (var i = 0; i < n; i++) {
        var it = rep.itemAt(i)
        if (!it) continue
        var cx = it.x + it.width / 2, cy = it.y + it.height / 2
        var d = Math.abs(px - cx) + Math.abs(py - cy) * 3
        if (d < bestD) { bestD = d; best = i; after = px > cx }
      }
      return best + (after ? 1 : 0)
    }

    Text {
      x: 14; y: 10
      text: lane.title + "   " + (lane.entries ? lane.entries.length : 0)
      color: Commons.Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body - 2
      font.letterSpacing: 2
    }

    Text {
      visible: !lane.entries || lane.entries.length === 0
      anchors.centerIn: parent
      text: "drop modules here"
      color: Util.alpha(Commons.Color.muted, 0.7)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
    }

    Flow {
      id: flow
      x: 14
      y: 34
      width: lane.width - 28
      spacing: 8

      Repeater {
        id: rep
        model: lane.entries

        ModuleChip {
          id: chip
          moduleId: modelData ? modelData.id : ""
          lane: laneId
          laneIndex: index
          // Widgets used more than once (Studio's launcher / studio buttons) say which.
          name: modelData ? page.ctl.moduleLabel(modelData.id) + (modelData.role ? " · " + modelData.role : "") : ""
          stripe: modelData ? P.segmentBase(page.ctl.res, laneId, index, laneEntries.length, modelData.id) : Commons.Color.accent
          dimmed: page.dragging && page.dragLane === laneId && page.dragIndex === index
          onDragStarted: function(x, y) { page.beginDrag(chip, modelData.id, laneId, index, x, y) }
          onDragMoved: function(x, y) { page.moveGhost(chip, x, y) }
          onDragEnded: page.endDrag()
          onRemoveRequested: page.ctl.removeEntry(laneId, index)
        }
      }
    }

    // insertion marker
    Rectangle {
      readonly property var target: page.hoverLane === lane.name && rep.count > 0
        ? rep.itemAt(Math.min(page.hoverIndex, rep.count - 1)) : null
      visible: page.hoverLane === lane.name && page.dragging && rep.count > 0 && target !== null
      width: 3
      height: 32
      color: Commons.Color.accent
      x: flow.x + (target ? (page.hoverIndex >= rep.count ? target.x + target.width + 3 : target.x - 6) : 0)
      y: flow.y + (target ? target.y : 0)
    }

    DropArea {
      anchors.fill: parent
      keys: ["module"]
      onPositionChanged: function(drag) {
        page.hoverLane = lane.name
        page.hoverIndex = lane.insertIndex(drag.x - flow.x, drag.y - flow.y)
      }
      onEntered: function(drag) { page.hoverLane = lane.name }
      onExited: if (page.hoverLane === lane.name) page.hoverLane = ""
      onDropped: function(drop) { page.finishDrop(lane.name, lane.insertIndex(drop.x - flow.x, drop.y - flow.y)) }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 10

    Lane { name: "left"; title: "LEFT" }
    Lane { name: "center"; title: "CENTER" }
    Lane { name: "right"; title: "RIGHT" }

    // ---- tray (also the remove zone)
    Rectangle {
      id: tray
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 90
      color: trayDrop.containsDrag && page.dragLane !== "tray" ? Util.alpha(Commons.Color.urgent, 0.12) : Util.alpha(Commons.Color.menu.text, 0.025)
      border.width: 1
      border.color: trayDrop.containsDrag && page.dragLane !== "tray" ? Commons.Color.urgent : Util.alpha(Commons.Color.menu.border, 0.45)

      Text {
        x: 14; y: 10
        text: trayDrop.containsDrag && page.dragLane !== "tray" ? "DROP TO REMOVE" : "AVAILABLE   ·   drag onto a lane"
        color: trayDrop.containsDrag && page.dragLane !== "tray" ? Commons.Color.urgent : Commons.Color.muted
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body - 2
        font.letterSpacing: 2
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 6
        width: 200
        height: 24
        color: "transparent"
        border.width: 1
        border.color: searchField.activeFocus ? Commons.Color.accent : Util.alpha(Commons.Color.menu.border, 0.6)
        Text {
          visible: searchField.text === ""
          anchors.verticalCenter: parent.verticalCenter
          x: 8
          text: "Search modules"
          color: Util.alpha(Commons.Color.muted, 0.8)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 1
        }
        TextInput {
          id: searchField
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          verticalAlignment: TextInput.AlignVCenter
          color: Commons.Color.menu.text
          selectionColor: Commons.Color.accent
          selectedTextColor: Commons.Color.background
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body - 1
          onTextChanged: page.query = text
        }
      }

      Flickable {
        x: 14
        y: 34
        width: parent.width - 28
        height: parent.height - 44
        contentWidth: width
        contentHeight: trayFlow.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Flow {
          id: trayFlow
          width: parent.width
          spacing: 8

          Repeater {
            model: page.filteredModules
            ModuleChip {
              id: tchip
              moduleId: modelData ? modelData.id : ""
              lane: "tray"
              laneIndex: index
              name: modelData ? page.ctl.moduleLabel(modelData.id) : ""
              multi: modelData.barWidget && modelData.barWidget.allowMultiple === true
              stripe: Commons.Color.accent
              onDragStarted: function(x, y) { page.beginDrag(tchip, modelData.id, "tray", index, x, y) }
              onDragMoved: function(x, y) { page.moveGhost(tchip, x, y) }
              onDragEnded: page.endDrag()
            }
          }
        }
      }

      Text {
        visible: page.ctl.availableModules.length === 0
        anchors.centerIn: parent
        text: "every module is on the bar"
        color: Commons.Color.muted
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }

      DropArea {
        id: trayDrop
        anchors.fill: parent
        keys: ["module"]
        onDropped: function(drop) {
          if (page.dragLane !== "tray") page.ctl.removeEntry(page.dragLane, page.dragIndex)
        }
      }
    }
  }

  // ---- drag ghost
  Rectangle {
    id: ghost
    visible: page.dragging
    z: 100
    width: ghostLabel.implicitWidth + 24
    height: 34
    color: Commons.Color.menu.background
    border.width: 2
    border.color: Commons.Color.accent
    opacity: 0.95
    Drag.active: page.dragging
    Drag.keys: ["module"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    Text {
      id: ghostLabel
      anchors.centerIn: parent
      color: Commons.Color.accent
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body + 1
    }
  }
}

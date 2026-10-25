import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Bar button + dropdown for picking Hyprland animation presets. The actual
// work lives in bin/omarchy-animations, which renders the preset into
// ~/.config/hypr/animation_preset.lua and reloads Hyprland; this panel only
// lists presets, shows the current one, and calls the script.
Panel {
  id: root

  // The bar is attached after the widget is created; until then, theme defaults.
  readonly property color barForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string barFont: bar ? bar.fontFamily : Style.font.family
  moduleName: "omacraft.animations"
  ipcTarget: "omacraft.animations"

  readonly property string script: decodeURIComponent(Qt.resolvedUrl("bin/omarchy-animations").toString().replace(/^file:\/\//, ""))
  readonly property int columns: 3
  // nf-md-auto_fix (U+F0068) as a surrogate pair.
  readonly property string glyph: "󰁨"

  property var presets: []
  property string currentPreset: ""
  property real speed: 1.0
  property real pendingSpeed: 1.0
  property string error: ""
  property int cursorIndex: 0
  property bool cursorActive: false
  property int hoverIndex: -1

  readonly property var currentInfo: presetById(currentPreset)
  readonly property var focusedInfo: hoverIndex >= 0 && hoverIndex < presets.length
    ? presets[hoverIndex]
    : (cursorActive && cursorIndex < presets.length ? presets[cursorIndex] : currentInfo)

  function presetById(id) {
    for (var i = 0; i < presets.length; i++)
      if (presets[i].id === id) return presets[i]
    return null
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function run(args) {
    if (applyProc.running) return
    root.error = ""
    applyProc.command = ["python3", root.script].concat(args)
    applyProc.running = true
  }

  function applyPreset(id) {
    root.currentPreset = id
    run(["apply", id, "--speed", String(root.pendingSpeed)])
  }

  function applySpeed(value) {
    root.pendingSpeed = Math.round(value * 20) / 20
    if (Math.abs(root.pendingSpeed - root.speed) < 0.001) return
    run(["speed", String(root.pendingSpeed)])
  }

  function moveCursor(dx, dy) {
    if (presets.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      var idx = presets.indexOf(currentInfo)
      cursorIndex = idx >= 0 ? idx : 0
      return
    }
    var next = cursorIndex + dx + dy * columns
    cursorIndex = Math.max(0, Math.min(presets.length - 1, next))
  }

  function speedLabel(value) {
    return (Math.round(value * 100) / 100).toString() + "×"
  }

  Component.onCompleted: refresh()
  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      hoverIndex = -1
      error = ""
      refresh()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: ["python3", root.script, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.presets = data.presets || []
          root.currentPreset = data.preset || "omarchy"
          root.speed = Number(data.speed) || 1.0
          root.pendingSpeed = root.speed
        } catch (e) {
          root.error = "Could not read animation presets"
        }
      }
    }
  }

  Process {
    id: applyProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.error = message.replace(/^omarchy-animations:\s*/, "")
      }
    }
    onExited: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    tooltipText: root.currentInfo ? "Animations: " + root.currentInfo.name : "Animations"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.run(["next"])
      else if (b === Qt.MiddleButton) root.run(["toggle"])
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: {
        if (root.cursorActive && root.cursorIndex < root.presets.length)
          root.applyPreset(root.presets[root.cursorIndex].id)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: root.glyph
            color: root.barForeground
            font.family: root.barFont
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            RotationAnimation on rotation {
              running: applyProc.running && !Style.reduceMotion
              loops: Animation.Infinite
              from: -12; to: 12
              duration: 300
              direction: RotationAnimation.Shortest
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Animations"
              color: root.barForeground
              font.family: root.barFont
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: ((root.currentInfo ? root.currentInfo.name : root.currentPreset) + " · " + root.speedLabel(root.speed)).toUpperCase()
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.barFont
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator { foreground: root.barForeground }

        // ---------- Presets ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "PRESETS"
            foreground: root.barForeground
            fontFamily: root.barFont
          }

          Grid {
            id: grid
            width: parent.width
            columns: root.columns
            columnSpacing: Style.space(6)
            rowSpacing: Style.space(6)

            readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

            Repeater {
              model: root.presets

              Button {
                required property var modelData
                required property int index
                width: grid.cellWidth
                text: modelData.name + (modelData.custom ? " ✦" : "")
                fontSize: Style.font.bodySmall
                foreground: root.barForeground
                fontFamily: root.barFont
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.currentPreset === modelData.id
                hasCursor: root.cursorActive && root.cursorIndex === index
                onClicked: root.applyPreset(modelData.id)
                onHovered: function(h) {
                  if (h) root.hoverIndex = index
                  else if (root.hoverIndex === index) root.hoverIndex = -1
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.focusedInfo ? root.focusedInfo.description : ""
            color: root.barForeground
            opacity: 0.6
            font.family: root.barFont
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }
        }

        PanelSeparator { foreground: root.barForeground }

        // ---------- Speed ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: speedHeader.implicitHeight

            PanelSectionHeader {
              id: speedHeader
              anchors.left: parent.left
              text: "SPEED"
              foreground: root.barForeground
              fontFamily: root.barFont
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: speedHeader.verticalCenter
              text: root.speedLabel(slider.liveValue)
              color: root.barForeground
              font.family: root.barFont
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            PanelSlider {
              id: slider
              bar: root.bar
              width: parent.width - resetButton.width - parent.spacing
              anchors.verticalCenter: parent.verticalCenter
              minimum: 0.25
              maximum: 3
              step: 0.05
              value: root.pendingSpeed
              onReleased: function(value) { root.applySpeed(value) }
            }

            Button {
              id: resetButton
              text: "1×"
              tooltipText: "Reset to preset speed"
              fontSize: Style.font.bodySmall
              foreground: root.barForeground
              fontFamily: root.barFont
              bordered: true
              active: Math.abs(root.speed - 1) < 0.001
              onClicked: root.applySpeed(1)
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.error !== ""
          width: parent.width
          text: root.error
          color: Commons.Color.urgent
          font.family: root.barFont
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Right click: next preset · Middle click: toggle off"
          color: root.barForeground
          opacity: 0.4
          font.family: root.barFont
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}

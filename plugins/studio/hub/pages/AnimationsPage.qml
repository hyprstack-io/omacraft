import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."

// Hyprland animation presets. The presets, curves and the generated
// ~/.config/hypr/animation_preset.lua belong to the omacraft.animations plugin;
// this page drives its omarchy-animations script so both stay in step.
Flickable {
  id: page

  property var hub
  property var store
  property var launcher

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  readonly property string script: decodeURIComponent(Qt.resolvedUrl("../../../omacraft.animations/bin/omarchy-animations").toString().replace(/^file:\/\//, ""))

  property var status: ({})
  property bool available: true
  property string error: ""
  property string busyPreset: ""
  readonly property bool busy: applyProc.running
  readonly property string current: status.preset || ""
  readonly property real speed: Number(status.speed) || 1
  readonly property var presets: status.presets || []

  readonly property var glyphs: ({
    omarchy: "◈", off: "■", snappy: "⚡", minimal: "◌", smooth: "≈", fluid: "◠",
    springy: "⌇", bouncy: "⤒", jelly: "◍", elastic: "⟿", slide: "⇥", vertical: "⇡",
    gnome: "◫", dreamy: "☁", arcade: "▦", zen: "○", snap: "✦"
  })

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function run(args, preset) {
    if (applyProc.running) return
    page.error = ""
    page.busyPreset = preset || ""
    applyProc.command = ["python3", page.script].concat(args)
    applyProc.running = true
  }

  // Load when the page first shows, and again whenever Studio reopens on it.
  onVisibleChanged: if (visible) refresh()
  Connections {
    target: page.hub
    function onOpenedChanged() { if (page.hub.opened && page.visible) page.refresh() }
  }

  Process {
    id: statusProc
    command: ["python3", page.script, "status", "--json"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function(exitCode) {
      page.available = exitCode === 0
      if (exitCode !== 0) return
      try { page.status = JSON.parse(statusOut.text) } catch (e) { page.error = "Could not read the animation presets" }
    }
  }

  Process {
    id: applyProc
    stderr: StdioCollector { id: applyErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        page.error = String(applyErr.text || "").trim().replace(/^omarchy-animations:\s*/, "") || "Could not apply the preset"
      page.busyPreset = ""
      page.refresh()
    }
  }

  ColumnLayout {
    id: column
    width: page.width
    spacing: Style.space(14)

    PageHeader {
      Layout.fillWidth: true
      title: "Animations"
      subtitle: "How windows, workspaces, fades and layers move in Hyprland. Wallpaper changes have their own style under Transitions."
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily

      Button {
        visible: page.available
        text: page.current === "off" ? "Turn on" : "Turn off"
        iconText: page.current === "off" ? "▶" : "■"
        tooltipText: page.current === "off" ? "Back to the last preset" : "Switch animations off"
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        iconSpinning: page.busy && page.busyPreset === "toggle"
        onClicked: page.run(["toggle"], "toggle")
      }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: !page.available || page.error !== ""
      implicitHeight: noticeText.implicitHeight + Style.space(20)
      radius: Style.cornerRadius > 0 ? Style.space(8) : 0
      color: Util.alpha(Commons.Color.urgent, 0.12)
      Text {
        id: noticeText
        anchors.fill: parent
        anchors.margins: Style.space(10)
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: !page.available
          ? "The omacraft.animations plugin isn't installed, and this page uses its presets. Expected: " + page.script
          : "⚠  " + page.error
        color: page.hub.fg
        font.family: page.hub.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    SectionLabel { Layout.fillWidth: true; visible: page.available; text: "Preset"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    GridLayout {
      Layout.fillWidth: true
      visible: page.available
      columns: Math.max(3, Math.floor(page.width / Style.space(170)))
      columnSpacing: Style.space(8)
      rowSpacing: Style.space(8)

      Repeater {
        model: page.presets
        ActionCard {
          required property var modelData
          readonly property bool inUse: page.current === modelData.id
          Layout.fillWidth: true
          Layout.fillHeight: true
          glyph: page.glyphs[modelData.id] || "◆"
          title: modelData.name
          description: modelData.description || ""
          highlighted: inUse
          badge: page.busy && page.busyPreset === modelData.id ? "applying…"
            : (inUse ? "✓ in use" : (modelData.custom ? "custom" : ""))
          foreground: page.hub.fg
          accent: page.hub.accent
          fontFamily: page.hub.fontFamily
          onClicked: page.run(["apply", modelData.id], modelData.id)
        }
      }
    }

    SectionLabel { Layout.fillWidth: true; visible: page.available; text: "Speed"; foreground: page.hub.fg; fontFamily: page.hub.fontFamily }

    SettingRow {
      Layout.fillWidth: true
      visible: page.available
      label: "Speed"
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      PanelSlider {
        id: speedSlider
        width: Style.space(320)
        anchors.verticalCenter: parent.verticalCenter
        minimum: 0.25
        maximum: 3
        step: 0.05
        enabled: page.current !== "off"
        trackColor: Util.alpha(page.hub.fg, 0.18)
        fillColor: page.hub.accent
        knobColor: page.hub.fg
        value: page.speed
        onReleased: function(value) { page.run(["speed", String(Math.round(value * 100) / 100)], "speed") }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: speedSlider.liveValue.toFixed(2) + "×"
        color: page.hub.fg
        font.family: page.hub.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: "Reset"
        tooltipText: "Back to the preset's own speed (1×)"
        fontSize: Style.font.caption
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        enabled: page.current !== "off" && page.speed !== 1
        onClicked: page.run(["speed", "1"], "speed")
      }
    }

    Text {
      Layout.fillWidth: true
      visible: page.available
      wrapMode: Text.Wrap
      text: "1× is the preset's own pace; higher is faster. Presets are written to " + (page.status.file || "~/.config/hypr/animation_preset.lua")
        + " and Hyprland reloads on the spot. Add your own presets in ~/.config/omarchy/animation-presets.json."
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}

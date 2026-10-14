import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Hyprland animation presets and their speed: the omacraft.animations bar
// widget's panel, with the Lua each preset writes beside it.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    property int selected: Math.max(0, indexOf(animations.preset))
    readonly property var selectedPreset: animations.presets[selected] || ({})
    readonly property int columns: Math.max(2, Math.floor(grid.width / 190))
    readonly property var shortcuts: [
        { keys: "← → ↑ ↓", action: "Choose a preset (its Lua shows on the right)" },
        { keys: "Space", action: "Apply the chosen preset" },
        { keys: "T", action: "Turn animations off, or back on" },
        { keys: "+ / −", action: "Faster / slower" },
        { keys: "0", action: "Back to the preset's own speed" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" }
    ]

    function indexOf(id) {
        for (let i = 0; i < animations.presets.length; i++)
            if (animations.presets[i].id === id)
                return i;
        return -1;
    }
    function move(step) {
        selected = Math.max(0, Math.min(animations.presets.length - 1, selected + step));
    }
    function handleEscape() {
        if (animations.error !== "" || animations.notice !== "") {
            animations.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}

    onActiveChanged: if (active) animations.refresh()
    onSelectedPresetChanged: if (selectedPreset.id) animations.preview(selectedPreset.id)
    Connections {
        target: animations
        function onChanged() { if (page.selectedPreset.id) animations.preview(page.selectedPreset.id) }
    }

    readonly property bool keys: active && keysFree && animations.available && !animations.busy
    Shortcut { sequence: "Left"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.move(-1) }
    Shortcut { sequence: "Right"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.move(1) }
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.move(-page.columns) }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.move(page.columns) }
    Shortcut { sequences: ["Space", "Return", "Enter"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.apply(page.selectedPreset.id) }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.toggle() }
    Shortcut { sequences: ["+", "="]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.setSpeed(animations.speed + 0.25) }
    Shortcut { sequence: "-"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.setSpeed(animations.speed - 0.25) }
    Shortcut { sequence: "0"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.setSpeed(1) }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.redo() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Animations"
            subtitle: "Hyprland animation presets and their speed, written to ~/.config/hypr/animation_preset.lua"
            glyph: "\u{f0d6d}"
            BusyIndicator { running: animations.busy; visible: animations.busy; implicitWidth: 28; implicitHeight: 28 }
            Button { text: "Undo"; flat: true; focusPolicy: Qt.NoFocus; enabled: animations.canUndo && !animations.busy; onClicked: animations.undo() }
            Button { text: "Redo"; flat: true; focusPolicy: Qt.NoFocus; enabled: animations.canRedo && !animations.busy; onClicked: animations.redo() }
            Button { text: "My presets…"; flat: true; focusPolicy: Qt.NoFocus; visible: animations.available; onClicked: animations.openCustomPresets() }
        }

        NotInstalled {
            visible: !animations.available
            pluginId: "omacraft.animations"
            what: "The presets and the script that writes them come with the Animations plugin."
        }

        MessageBar {
            error: animations.error
            notice: animations.notice
            onDismissed: animations.dismissMessages()
        }

        // The speed applies to whichever preset is in use.
        Card {
            visible: animations.available
            Layout.fillWidth: true
            implicitHeight: speedRow.implicitHeight + 28
            RowLayout {
                id: speedRow
                anchors.fill: parent
                anchors.margins: 14
                anchors.leftMargin: 18
                spacing: 14
                ColumnLayout {
                    spacing: 0
                    Label { text: "In use"; color: "#8a8a93"; font.pixelSize: 11 }
                    Label {
                        text: {
                            const i = page.indexOf(animations.preset);
                            return i >= 0 ? animations.presets[i].name : animations.preset;
                        }
                        color: "white"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                }
                Rectangle { width: 1; Layout.fillHeight: true; color: "#26262b" }
                SliderRow {
                    label: "Speed"
                    from: 0.25
                    to: 3
                    stepSize: 0.05
                    value: animations.speed
                    suffix: "×"
                    onMoved: value => animations.setSpeed(value)
                }
                Button { text: "1×"; flat: true; focusPolicy: Qt.NoFocus; onClicked: animations.setSpeed(1) }
                KeyCap { text: "+ −" }
                Rectangle { width: 1; Layout.fillHeight: true; color: "#26262b" }
                Button {
                    text: animations.preset === "off" ? "Turn back on" : "Turn off"
                    focusPolicy: Qt.NoFocus
                    onClicked: animations.toggle()
                }
                KeyCap { text: "T" }
            }
        }

        // Shapes and border colours, on top of whichever preset is in use.
        Card {
            visible: animations.available && animations.windowStyles.length > 0
            Layout.fillWidth: true
            implicitHeight: lookColumn.implicitHeight + 24
            ColumnLayout {
                id: lookColumn
                anchors.fill: parent
                anchors.margins: 12
                anchors.leftMargin: 18
                spacing: 8
                Repeater {
                    model: [
                        { label: "Window shape", kind: "windows", list: animations.windowStyles, value: animations.windowStyle },
                        { label: "Workspace shape", kind: "workspaces", list: animations.workspaceStyles, value: animations.workspaceStyle }
                    ]
                    delegate: RowLayout {
                        id: styleRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Label { Layout.preferredWidth: 120; Layout.alignment: Qt.AlignTop; topPadding: 6; text: styleRow.modelData.label; color: "#d6d6da" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: styleRow.modelData.list
                                Chip {
                                    required property string modelData
                                    text: modelData === "preset" ? "Preset's own" : modelData
                                    chosen: styleRow.modelData.value === modelData
                                    enabled: !animations.busy
                                    onClicked: styleRow.modelData.kind === "windows" ? animations.setWindowStyle(modelData) : animations.setWorkspaceStyle(modelData)
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Label { Layout.preferredWidth: 120; Layout.alignment: Qt.AlignTop; topPadding: 6; text: "Window border"; color: "#d6d6da" }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Chip { text: "Theme's own"; chosen: animations.border === "theme"; onClicked: animations.setBorder("theme") }
                        Repeater {
                            model: animations.borders
                            delegate: Rectangle {
                                id: run
                                required property var modelData
                                readonly property bool chosen: animations.border === modelData.id
                                implicitWidth: runName.implicitWidth + 58
                                implicitHeight: 30
                                radius: 7
                                color: runHover.hovered ? "#1d1d21" : "#111113"
                                border.color: chosen ? theme.accent : "#26262b"
                                border.width: chosen ? 2 : 1
                                // The colour run as it wraps the window.
                                Rectangle {
                                    x: 8; anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 12; radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: "#" + run.modelData.colors[0] }
                                        GradientStop { position: 0.5; color: "#" + run.modelData.colors[Math.floor(run.modelData.colors.length / 2)] }
                                        GradientStop { position: 1; color: "#" + run.modelData.colors[run.modelData.colors.length - 1] }
                                    }
                                }
                                Label { id: runName; x: 46; anchors.verticalCenter: parent.verticalCenter; text: run.modelData.name; color: run.chosen ? theme.accent : "#d6d6da"; font.pixelSize: 12 }
                                HoverHandler { id: runHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: animations.setBorder(run.modelData.id) }
                            }
                        }
                    }
                }
                RowLayout {
                    visible: animations.border !== "theme"
                    Layout.fillWidth: true
                    spacing: 14
                    SwitchRow {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 300
                        label: "Spin the border"
                        hint: "The gradient turns around each window."
                        checked: animations.borderLoop
                        onToggled: on => animations.setBorderLoop(on)
                    }
                    SliderRow {
                        visible: animations.borderLoop
                        label: "One turn every"
                        from: 1
                        to: 10
                        stepSize: 1
                        decimals: 0
                        value: animations.borderSpeed
                        suffix: " s"
                        onMoved: value => animations.setBorderSpeed(Math.round(value))
                    }
                }
            }
        }

        RowLayout {
            visible: animations.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ScrollView {
                    id: gridScroll
                    anchors.fill: parent
                    anchors.margins: 12
                    contentWidth: availableWidth
                    clip: true

                    GridLayout {
                        id: grid
                        width: gridScroll.availableWidth
                        columns: page.columns
                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: animations.presets
                            delegate: Rectangle {
                                id: tile
                                required property var modelData
                                required property int index
                                readonly property bool inUse: animations.preset === modelData.id
                                readonly property bool chosen: page.selected === index
                                readonly property color tone: Qt.color(theme.accent)

                                Layout.fillWidth: true
                                implicitHeight: 74
                                radius: 9
                                color: inUse ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : hover.hovered ? "#1b1b1f" : "#111113"
                                border.color: chosen ? theme.accent : inUse ? Qt.rgba(tone.r, tone.g, tone.b, 0.5) : "#26262b"
                                border.width: chosen ? 2 : 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 11
                                    spacing: 3
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            text: tile.modelData.name + (tile.modelData.custom ? "  ✦" : "")
                                            color: tile.inUse ? theme.accent : "white"
                                            font.weight: Font.DemiBold
                                        }
                                        Item { Layout.fillWidth: true }
                                        Label { visible: tile.inUse; text: "in use"; color: theme.accent; font.pixelSize: 10 }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: tile.modelData.description || ""
                                        color: "#8a8a93"
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }
                                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        page.selected = tile.index;
                                        animations.apply(tile.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // What the chosen preset writes, at the current speed.
            Card {
                Layout.preferredWidth: Math.min(460, page.width * 0.4)
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        SectionLabel { text: "Lua for " + (page.selectedPreset.name || "") }
                        Item { Layout.fillWidth: true }
                        AccentButton {
                            text: "Apply"
                            enabled: page.selectedPreset.id !== animations.preset && !animations.busy
                            onClicked: animations.apply(page.selectedPreset.id)
                        }
                        KeyCap { text: "Space" }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: "#0b0b0d"
                        border.color: "#26262b"
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            Label {
                                text: animations.lua
                                color: "#a9a9b2"
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Presets marked ✦ are yours, from " + animations.customPath.replace(/^\/home\/[^/]+/, "~") + "."
                        color: "#5f5f68"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}

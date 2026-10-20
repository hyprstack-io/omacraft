import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Hyprland's animations: presets, their speed, window and workspace shapes,
// and the window border. The stage plays the preset in use (or the one under
// the pointer) as Hyprland would: a window opening, a workspace switch, the
// window closing, inside its border.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    property int tab: startTab === "motion" ? 1 : startTab === "borders" ? 2 : startTab === "lua" ? 3 : 0
    property string group: "all"
    // The keyboard's place in the grid; its Lua shows on the Lua tab.
    property int selected: Math.max(0, indexOf(animations.preset))
    readonly property var selectedPreset: shown[selected] || ({})
    readonly property int columns: Math.max(2, Math.floor(grid.width / 250))

    readonly property var shown: animations.presets.filter(p => group === "all" || (group === "yours") === (p.custom === true))
    readonly property var inUse: animations.presets.find(p => p.id === animations.preset) || ({})

    // A tile being hovered, played on the stage.
    property var previewPreset: null
    property string previewWindowStyle: ""
    property string previewWorkspaceStyle: ""
    property string previewBorder: ""
    property string previewName: ""
    function preview(name, fields) {
        previewName = name;
        previewPreset = fields.preset || null;
        previewWindowStyle = fields.windowStyle || "";
        previewWorkspaceStyle = fields.workspaceStyle || "";
        previewBorder = fields.border || "";
    }
    function endPreview(name) {
        if (previewName !== name) return;
        previewName = "";
        previewPreset = null;
        previewWindowStyle = "";
        previewWorkspaceStyle = "";
        previewBorder = "";
    }
    readonly property var stagePreset: previewPreset || inUse
    readonly property string stageBorderId: previewBorder !== "" ? previewBorder : animations.border
    function borderColors(id) {
        const run = animations.borders.find(b => b.id === id);
        return run ? run.colors.map(c => "#" + String(c).replace("#", "")) : [];
    }
    function motionSummary(p) {
        const m = p.animations || {};
        const secs = v => v && typeof v.length === "number" ? (Number(v[0]) / 10 / animations.speed).toFixed(2) + "s" : "";
        if (p.enabled === false) return "No animations";
        return ["open " + secs(m.windowsIn || m.windows || m.global), "workspaces " + secs(m.workspaces || m.global)]
               .filter(s => !s.endsWith(" ")).join(" · ");
    }

    readonly property var shortcuts: [
        { keys: "P / M / B / L", action: "Presets, Motion, Borders, Lua" },
        { keys: "← → ↑ ↓", action: "Choose a preset (it plays on the stage)" },
        { keys: "Space", action: "Apply the chosen preset" },
        { keys: "T", action: "Turn animations off, or back on" },
        { keys: "+ / −", action: "Faster / slower" },
        { keys: "0", action: "Back to the preset's own speed" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" }
    ]

    function indexOf(id) {
        for (let i = 0; i < shown.length; i++)
            if (shown[i].id === id)
                return i;
        return -1;
    }
    function move(step) {
        selected = Math.max(0, Math.min(shown.length - 1, selected + step));
        grid.positionViewAtIndex(selected, GridView.Contain);
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
    onGroupChanged: selected = Math.max(0, indexOf(animations.preset))
    Connections {
        target: animations
        function onChanged() { if (page.selectedPreset.id) animations.preview(page.selectedPreset.id) }
    }

    readonly property bool keys: active && keysFree && animations.available && !animations.busy
    Shortcut { sequence: "P"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 0 }
    Shortcut { sequence: "M"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 1 }
    Shortcut { sequence: "B"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 2 }
    Shortcut { sequence: "L"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 3 }
    Shortcut { sequence: "Left"; context: Qt.ApplicationShortcut; enabled: page.keys && page.tab === 0; onActivated: page.move(-1) }
    Shortcut { sequence: "Right"; context: Qt.ApplicationShortcut; enabled: page.keys && page.tab === 0; onActivated: page.move(1) }
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: page.keys && page.tab === 0; onActivated: page.move(-page.columns) }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: page.keys && page.tab === 0; onActivated: page.move(page.columns) }
    Shortcut { sequences: ["Space", "Return", "Enter"]; context: Qt.ApplicationShortcut; enabled: page.keys && (page.tab === 0 || page.tab === 3); onActivated: animations.apply(page.selectedPreset.id) }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.toggle() }
    Shortcut { sequences: ["+", "="]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.setSpeed(animations.speed + 0.25) }
    Shortcut { sequence: "-"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.setSpeed(animations.speed - 0.25) }
    Shortcut { sequence: "0"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.setSpeed(1) }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: animations.redo() }

    // A tile: something drawn, a name, a line.
    component Tile: Rectangle {
        id: tile
        property string title
        property string tag
        property string subtitle
        property bool chosen: false
        property bool marked: false
        default property alias art: artHolder.data
        signal picked()
        signal previewWanted(bool on)
        readonly property color tone: Qt.color(theme.accent)
        readonly property bool hovered: tileHover.hovered
        radius: 10
        color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : hovered ? theme.hover : theme.inset
        border.color: chosen ? theme.accent : marked ? theme.textMuted : hovered ? theme.borderStrong : theme.border
        border.width: chosen || marked ? 2 : 1
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                clip: true
                color: theme.sunken
                Item { id: artHolder; anchors.fill: parent }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Label { Layout.fillWidth: true; text: tile.title; color: tile.chosen ? theme.accent : theme.text; font.weight: Font.DemiBold; font.pixelSize: 12; elide: Text.ElideRight }
                Label { visible: tile.tag !== ""; Layout.maximumWidth: tile.width * 0.45; text: tile.tag; color: tile.chosen ? theme.accent : theme.textFaint; font.pixelSize: 10; elide: Text.ElideRight }
            }
            Label { visible: tile.subtitle !== ""; Layout.fillWidth: true; text: tile.subtitle; color: theme.textDim; font.pixelSize: 10; elide: Text.ElideRight }
        }
        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: tile.previewWanted(hovered) }
        TapHandler { onTapped: tile.picked() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        PageHeader {
            title: "Animations"
            subtitle: "Hyprland's animations, played on the stage and written to ~/.config/hypr/animation_preset.lua"
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

        // --- the stage: the preset, playing ---
        Stage {
            id: stage
            visible: animations.available
            Layout.fillWidth: true
            Layout.preferredHeight: 190
            windows: false
            previewing: page.previewName !== ""
            caption: page.previewName !== "" ? "Preview · " + page.previewName + " · click to apply"
                   : [page.inUse.name || animations.preset, animations.speed.toFixed(2) + "×",
                      animations.windowStyle !== "preset" ? animations.windowStyle + " windows" : "",
                      animations.workspaceStyle !== "preset" ? animations.workspaceStyle + " workspaces" : "",
                      animations.border !== "theme" ? ((animations.borders.find(b => b.id === animations.border) || {}).name || animations.border) + " border" : ""]
                     .filter(s => s !== "").join(" · ")

            AnimStage {
                anchors.fill: parent
                anchors.margins: 14
                anchors.rightMargin: speedBox.width + 28
                motion: page.stagePreset.animations || ({})
                enabled: page.stagePreset.enabled !== false && page.stagePreset.id !== "off"
                curves: animations.curves
                speed: animations.speed
                windowStyle: page.previewWindowStyle !== "" ? page.previewWindowStyle : animations.windowStyle
                workspaceStyle: page.previewWorkspaceStyle !== "" ? page.previewWorkspaceStyle : animations.workspaceStyle
                borderColors: page.borderColors(page.stageBorderId)
                borderLoop: animations.borderLoop
                borderSeconds: animations.borderSpeed
                playing: page.active
            }

            // Speed and on/off, always at hand.
            Rectangle {
                id: speedBox
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                width: 210
                height: speedColumn.implicitHeight + 20
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.42)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                ColumnLayout {
                    id: speedColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Speed"; color: "#dddddd"; font.pixelSize: 11; Layout.fillWidth: true }
                        Label { text: speedSlider.value.toFixed(2) + "×"; color: theme.accent; font.family: "monospace"; font.pixelSize: 12 }
                    }
                    Slider {
                        id: speedSlider
                        Layout.fillWidth: true
                        from: 0.25; to: 3; stepSize: 0.05
                        value: animations.speed
                        focusPolicy: Qt.NoFocus
                        onPressedChanged: if (!pressed && Math.abs(value - animations.speed) > 1e-6) animations.setSpeed(value)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Button { text: "1×"; flat: true; focusPolicy: Qt.NoFocus; onClicked: animations.setSpeed(1) }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: animations.preset === "off" ? "Turn on" : "Turn off"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            onClicked: animations.toggle()
                        }
                    }
                }
            }
        }

        TabBar {
            visible: animations.available
            Layout.fillWidth: true
            currentIndex: page.tab
            onCurrentIndexChanged: page.tab = currentIndex
            background: null
            Repeater {
                model: ["Presets", "Motion", "Borders", "Lua"]
                TabButton {
                    required property string modelData
                    text: modelData
                    focusPolicy: Qt.NoFocus
                    width: implicitWidth + 24
                }
            }
        }

        StackLayout {
            visible: animations.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: page.tab

            // ================= Presets =================
            ColumnLayout {
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Segmented {
                        model: [{ id: "all", name: "All" }, { id: "builtin", name: "Built in" }, { id: "yours", name: "Yours" }]
                        current: page.group
                        onPicked: id => page.group = id
                    }
                    Label {
                        Layout.leftMargin: 8
                        Layout.fillWidth: true
                        text: "Hover to play one on the stage; click to use it. Each tile draws the curve its windows open on."
                        color: theme.textDim
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Label { text: page.shown.length; color: theme.textFaint; font.pixelSize: 11 }
                }
                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / page.columns)
                    cellHeight: 136
                    model: page.shown
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property var m: modelData.animations || ({})
                        readonly property var openPart: m.windowsIn || m.windows || m.global
                        width: grid.cellWidth
                        height: grid.cellHeight
                        Tile {
                            id: presetTile
                            anchors.fill: parent
                            anchors.margins: 5
                            title: cell.modelData.name + (cell.modelData.custom ? "  ✦" : "")
                            tag: animations.preset === cell.modelData.id ? "in use" : page.motionSummary(cell.modelData)
                            subtitle: cell.modelData.description || ""
                            chosen: animations.preset === cell.modelData.id
                            marked: page.selected === cell.index && !chosen
                            onPreviewWanted: on => on ? page.preview(cell.modelData.name, { preset: cell.modelData }) : page.endPreview(cell.modelData.name)
                            onPicked: { page.selected = cell.index; page.endPreview(cell.modelData.name); animations.apply(cell.modelData.id); }
                            AnimStage {
                                anchors.fill: parent
                                anchors.margins: 4
                                anchors.rightMargin: 58
                                compact: true
                                workspaces: false
                                motion: cell.m
                                enabled: cell.modelData.enabled !== false && cell.modelData.id !== "off"
                                curves: animations.curves
                                speed: animations.speed
                                borderColors: page.borderColors(animations.border)
                                playing: presetTile.hovered
                            }
                            CurveGraph {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 6
                                width: 48
                                height: 40
                                visible: cell.openPart !== undefined && cell.openPart !== false
                                curve: cell.openPart && cell.openPart.length ? (animations.curves[cell.openPart[1]] || { type: "bezier", points: [[0.05, 0.9], [0.1, 1.05]] }) : ({ type: "bezier", points: [[0, 0], [1, 1]] })
                            }
                        }
                    }
                }
            }

            // ================= Motion =================
            ScrollView {
                id: motionScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: motionScroll.availableWidth
                    spacing: 12
                    Repeater {
                        model: [
                            { label: "Window shape", hint: "How windows open and close, over whichever preset is in use.", kind: "windows", list: animations.windowStyles, value: animations.windowStyle },
                            { label: "Workspace shape", hint: "How one workspace gives way to the next.", kind: "workspaces", list: animations.workspaceStyles, value: animations.workspaceStyle }
                        ]
                        delegate: Card {
                            id: shapeCard
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: shapeColumn.implicitHeight + 28
                            ColumnLayout {
                                id: shapeColumn
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8
                                RowLayout {
                                    SectionLabel { text: shapeCard.modelData.label }
                                    Label { text: shapeCard.modelData.hint; color: theme.textDim; font.pixelSize: 11; Layout.leftMargin: 8 }
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: shapeCard.modelData.list
                                        Tile {
                                            id: shapeTile
                                            required property string modelData
                                            width: 168
                                            height: 116
                                            title: modelData === "preset" ? "Preset's own" : modelData
                                            chosen: shapeCard.modelData.value === modelData
                                            readonly property var fields: shapeCard.modelData.kind === "windows" ? { windowStyle: modelData } : { workspaceStyle: modelData }
                                            onPreviewWanted: on => on ? page.preview(title, fields) : page.endPreview(title)
                                            onPicked: {
                                                page.endPreview(title);
                                                if (shapeCard.modelData.kind === "windows") animations.setWindowStyle(modelData);
                                                else animations.setWorkspaceStyle(modelData);
                                            }
                                            AnimStage {
                                                anchors.fill: parent
                                                anchors.margins: 4
                                                compact: true
                                                windows: shapeCard.modelData.kind === "windows"
                                                workspaces: shapeCard.modelData.kind === "workspaces"
                                                motion: page.inUse.animations || ({})
                                                curves: animations.curves
                                                speed: animations.speed
                                                windowStyle: shapeCard.modelData.kind === "windows" ? shapeTile.modelData : animations.windowStyle
                                                workspaceStyle: shapeCard.modelData.kind === "workspaces" ? shapeTile.modelData : animations.workspaceStyle
                                                borderColors: page.borderColors(animations.border)
                                                playing: shapeTile.hovered
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: speedColumn2.implicitHeight + 28
                        ColumnLayout {
                            id: speedColumn2
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            SectionLabel { text: "Speed" }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                SliderRow { label: "All animations"; from: 0.25; to: 3; stepSize: 0.05; value: animations.speed; suffix: "×"; onMoved: v => animations.setSpeed(v) }
                                Button { text: "1×"; flat: true; focusPolicy: Qt.NoFocus; onClicked: animations.setSpeed(1) }
                                KeyCap { text: "+ −" }
                            }
                            SwitchRow {
                                label: "Animations"
                                hint: "Off sets the Off preset; on goes back to the one you had."
                                checked: animations.preset !== "off"
                                onToggled: animations.toggle()
                            }
                        }
                    }
                    Item { implicitHeight: 4 }
                }
            }

            // ================= Borders =================
            ScrollView {
                id: borderScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: borderScroll.availableWidth
                    spacing: 12
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: spinRow.implicitHeight + 28
                        RowLayout {
                            id: spinRow
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 18
                            SwitchRow {
                                Layout.fillWidth: false
                                Layout.preferredWidth: 320
                                enabled: animations.border !== "theme"
                                label: "Spin the border"
                                hint: "The colour run turns around each window."
                                checked: animations.borderLoop
                                onToggled: on => animations.setBorderLoop(on)
                            }
                            SliderRow {
                                enabled: animations.borderLoop && animations.border !== "theme"
                                label: "One turn every"
                                from: 1; to: 10; stepSize: 1; decimals: 0; suffix: " s"
                                value: animations.borderSpeed
                                onMoved: v => animations.setBorderSpeed(Math.round(v))
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(2, Math.floor(width / 220))
                        rowSpacing: 10
                        columnSpacing: 10
                        Repeater {
                            model: [{ id: "theme", name: "Theme's own", colors: [] }].concat(animations.borders)
                            delegate: Tile {
                                id: borderTile
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 130
                                title: modelData.name
                                tag: modelData.id === "theme" ? "follows Omarchy" : modelData.id === "wallpaper" ? "follows the wallpaper" : modelData.colors.length + " colours"
                                chosen: animations.border === modelData.id
                                onPreviewWanted: on => on ? page.preview(modelData.name + " border", { border: modelData.id }) : page.endPreview(modelData.name + " border")
                                onPicked: { page.endPreview(modelData.name + " border"); animations.setBorder(modelData.id); }
                                AnimStage {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    compact: true
                                    windows: false
                                    workspaces: false
                                    borderColors: page.borderColors(borderTile.modelData.id)
                                    borderLoop: borderTile.hovered || (borderTile.chosen && animations.borderLoop)
                                    borderSeconds: borderTile.hovered ? 2 : animations.borderSpeed
                                    playing: page.active
                                }
                            }
                        }
                    }
                    Item { implicitHeight: 4 }
                }
            }

            // ================= Lua =================
            RowLayout {
                spacing: 12
                Card {
                    Layout.preferredWidth: 280
                    Layout.fillHeight: true
                    ListView {
                        id: luaList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        spacing: 2
                        model: page.shown
                        currentIndex: page.selected
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            required property var modelData
                            required property int index
                            width: luaList.width - 10
                            height: 34
                            highlighted: page.selected === index
                            text: modelData.name + (animations.preset === modelData.id ? "   · in use" : "")
                            font.pixelSize: 12
                            onClicked: page.selected = index
                        }
                    }
                }
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            SectionLabel { text: "What " + (page.selectedPreset.name || "") + " writes, at " + animations.speed.toFixed(2) + "×" }
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
                            color: theme.sidebar
                            border.color: theme.border
                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 10
                                clip: true
                                TextArea {
                                    readOnly: true
                                    selectByMouse: true
                                    text: animations.lua
                                    color: theme.textMuted
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                    background: null
                                }
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Presets marked ✦ are yours, from " + animations.customPath.replace(/^\/home\/[^/]+/, "~") + " (My presets… opens it)."
                            color: theme.textFaint
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}

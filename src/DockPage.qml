import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// HyprDOCKN: the edge dock, its apps and commands, and a terminal tab per AI
// agent. The stage draws the dock as it is (or as a hovered look would make
// it), magnifying under the pointer; click an item on it to pick it.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    property int tab: startTab === "items" ? 1 : startTab === "agents" ? 2 : startTab === "placement" ? 3 : 0
    property string lookView: "presets"
    property bool panelPeek: false
    // The picked dock item, or agent (-1 a new one, -2 none).
    property int selItem: -1
    property int editing: -2
    readonly property var s: dock.settings

    // A look under the pointer, laid over the settings on the stage.
    property var previewSettings: null
    property string previewName: ""
    function preview(name, fields) { previewName = name; previewSettings = fields; }
    function endPreview(name) { if (previewName === name) { previewName = ""; previewSettings = null; } }
    readonly property var stageSettings: previewSettings ? Object.assign({}, s, previewSettings) : s

    readonly property var dockColors: ({ midnight: "#11111b", ink: "#000000", slate: "#1e293b", ocean: "#0b3954",
                                         forest: "#12372a", plum: "#2d1b3d", wine: "#3b0d1a", amber: "#3a2800",
                                         frost: "#dfe9f5", paper: "#f2efe9" })
    readonly property var accentColors: ({ red: "#f7768e", orange: "#ff9e64", yellow: "#e0af68", green: "#9ece6a",
                                           teal: "#73daca", cyan: "#7dcfff", blue: "#7aa2f7", purple: "#bb9af7",
                                           pink: "#ff79c6", white: "#ffffff" })

    // Whole looks: shape, tiles, colours, border and magnify together.
    readonly property var looks: [
        { id: "omarchy", name: "Omarchy", desc: "The dock as it ships, in your theme",
          set: { dockShape: "rounded", iconShape: "rounded", iconPlate: "hover", dockColor: "theme", accentColor: "theme", dockBorder: "subtle", magnify: false, opacity: 0.94 } },
        { id: "macos", name: "Cupertino", desc: "Squircles that swell under the pointer",
          set: { dockShape: "soft", iconShape: "squircle", iconPlate: "hover", dockColor: "theme", accentColor: "theme", dockBorder: "subtle", magnify: true, magnifyScale: 1.8, magnifyRange: 2, opacity: 0.86 } },
        { id: "glass", name: "Glass", desc: "Barely there: see-through, no border",
          set: { dockShape: "pill", iconShape: "circle", iconPlate: "hover", dockColor: "theme", accentColor: "theme", dockBorder: "none", magnify: true, magnifyScale: 1.4, magnifyRange: 2, opacity: 0.55 } },
        { id: "neon-edge", name: "Neon Edge", desc: "Fixed to the edge, cyan outlines on ink",
          set: { dockShape: "edge", iconShape: "circle", iconPlate: "outline", dockColor: "ink", accentColor: "cyan", dockBorder: "accent", magnify: false, opacity: 0.96 } },
        { id: "midnight", name: "Midnight", desc: "Deep blue-black, a gentle swell",
          set: { dockShape: "rounded", iconShape: "squircle", iconPlate: "hover", dockColor: "midnight", accentColor: "blue", dockBorder: "subtle", magnify: true, magnifyScale: 1.5, magnifyRange: 2, opacity: 0.94 } },
        { id: "paper", name: "Paper", desc: "Light and square, every tile showing",
          set: { dockShape: "square", iconShape: "square", iconPlate: "always", dockColor: "paper", accentColor: "orange", dockBorder: "subtle", magnify: false, opacity: 1 } },
        { id: "frost", name: "Frost", desc: "Icy pill with rounded tiles",
          set: { dockShape: "pill", iconShape: "rounded", iconPlate: "always", dockColor: "frost", accentColor: "blue", dockBorder: "none", magnify: true, magnifyScale: 1.6, magnifyRange: 3, opacity: 0.9 } },
        { id: "ocean", name: "Ocean", desc: "Teal accents on deep water",
          set: { dockShape: "rounded", iconShape: "circle", iconPlate: "always", dockColor: "ocean", accentColor: "teal", dockBorder: "accent", magnify: false, opacity: 0.94 } },
        { id: "forest", name: "Forest", desc: "Green on green, soft corners",
          set: { dockShape: "soft", iconShape: "rounded", iconPlate: "hover", dockColor: "forest", accentColor: "green", dockBorder: "subtle", magnify: true, magnifyScale: 1.5, magnifyRange: 2, opacity: 0.94 } },
        { id: "plum", name: "Plum", desc: "Diamonds in purple",
          set: { dockShape: "soft", iconShape: "diamond", iconPlate: "outline", dockColor: "plum", accentColor: "purple", dockBorder: "accent", magnify: false, opacity: 0.94 } },
        { id: "wine", name: "Wine", desc: "Pink on dark red, pill-shaped",
          set: { dockShape: "pill", iconShape: "circle", iconPlate: "hover", dockColor: "wine", accentColor: "pink", dockBorder: "subtle", magnify: true, magnifyScale: 1.7, magnifyRange: 2, opacity: 0.94 } },
        { id: "amber", name: "Amber", desc: "Warm terminal glow, outlined",
          set: { dockShape: "edge", iconShape: "square", iconPlate: "outline", dockColor: "amber", accentColor: "yellow", dockBorder: "accent", magnify: false, opacity: 0.96 } }
    ]
    function isLook(look) {
        for (const k in look.set) if (k !== "opacity" && k !== "magnifyScale" && k !== "magnifyRange" && s[k] !== look.set[k]) return false;
        return true;
    }
    function applyLook(look) {
        endPreview(look.name);
        for (const k in look.set) dock.set(k, look.set[k]);
    }
    readonly property var currentLook: looks.find(l => isLook(l)) || null

    readonly property var shortcuts: [
        { keys: "L / I / A / P", action: "Looks, Items, Agents, Placement" },
        { keys: "Space", action: "Show or hide the dock's panel" },
        { keys: "S", action: "Open the dock's own settings card" },
        { keys: "Delete", action: "Take the picked item off the dock" }
    ]

    function handleEscape() {
        if (page.editing !== -2) { page.editing = -2; return true; }
        if (page.selItem >= 0) { page.selItem = -1; return true; }
        if (dock.error !== "" || dock.notice !== "") { dock.dismissMessages(); return true; }
        return false;
    }
    function acceptDialog() {}
    function home(path) { return String(path || "").replace(/^\/home\/[^/]+/, "~"); }

    onActiveChanged: if (active) { dock.reload(); dock.refreshMonitors(); }

    readonly property bool keys: active && keysFree && dock.available
    Shortcut { sequence: "L"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 0 }
    Shortcut { sequence: "I"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 1 }
    Shortcut { sequence: "A"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 2 }
    Shortcut { sequences: ["P", "G"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 3 }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: dock.toggleDock() }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: dock.openDockSettings() }
    Shortcut {
        sequences: ["Delete", "Backspace"]
        context: Qt.ApplicationShortcut
        enabled: page.keys && page.selItem >= 0
        onActivated: { dock.removeItem(page.selItem); page.selItem = -1; }
    }

    // A tile with something drawn in it.
    component Tile: Rectangle {
        id: tile
        property string title
        property string tag
        property string subtitle
        property bool chosen: false
        default property alias art: artHolder.data
        signal picked()
        signal previewWanted(bool on)
        readonly property color tone: Qt.color(theme.accent)
        readonly property bool hovered: tileHover.hovered
        radius: 10
        color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : hovered ? theme.hover : theme.inset
        border.color: chosen ? theme.accent : hovered ? theme.borderStrong : theme.border
        border.width: chosen ? 2 : 1
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
                Label { Layout.fillWidth: true; text: tile.title; color: tile.chosen ? theme.accent : theme.text; font.weight: Font.DemiBold; font.pixelSize: 12; elide: Text.ElideRight }
                Label { visible: tile.tag !== ""; text: tile.tag; color: theme.textFaint; font.pixelSize: 10 }
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
            title: "HyprDOCKN"
            subtitle: "The edge dock, its apps and commands, and a terminal tab per AI agent"
            glyph: "\u{f06a9}"
            Button { text: "Show / hide panel"; flat: true; focusPolicy: Qt.NoFocus; enabled: dock.running; onClicked: dock.toggleDock() }
            Button { text: "Dock's own settings"; flat: true; focusPolicy: Qt.NoFocus; enabled: dock.running; onClicked: dock.openDockSettings() }
        }

        NotInstalled {
            visible: !dock.available
            pluginId: "omacraft.agentdock"
            what: "The dock is a shell panel from the HyprDOCKN plugin."
        }

        MessageBar {
            error: dock.error
            notice: dock.notice
            onDismissed: dock.dismissMessages()
        }

        MessageBar {
            visible: dock.available && !dock.running
            notice: "The dock isn't enabled. Changes here are saved and take effect when it starts. Enable it on the Plugins page."
        }

        // --- the stage: the dock on its edge ---
        Stage {
            id: stage
            visible: dock.available
            Layout.fillWidth: true
            // Tall enough that a long dock still reads.
            Layout.preferredHeight: Math.min(440, Math.max(260, stageDock.naturalHeight * 0.55 + 24))
            previewing: page.previewName !== ""
            edge: page.stageSettings.position || "right"
            edgeSize: stageDock.width + (page.stageSettings.gap || 10)
            captionRight: edge === "right" ? stageDock.width + (page.stageSettings.gap || 10) + 12 : 10
            caption: page.previewName !== "" ? "Preview · " + page.previewName + " · click to apply"
                   : [page.currentLook ? page.currentLook.name + " look" : "Your look", (page.s.position || "right") + " edge",
                      dock.dock.length + " items", dock.agents.filter(a => a.shown).length + " agent tabs",
                      page.s.magnify ? "point at it to magnify" : ""].filter(t => t !== "").join(" · ")

            DockPreview {
                id: stageDock
                s: page.stageSettings
                items: dock.dock
                agents: dock.agents
                interactive: page.previewName === ""
                panelOpen: page.panelPeek
                selectedIndex: page.tab === 1 ? page.selItem : -1
                fitHeight: stage.height - 24
                anchors.verticalCenter: parent.verticalCenter
                x: (page.stageSettings.position || "right") === "right" ? stage.width - width - Math.min(30, page.stageSettings.gap || 10) : Math.min(30, page.stageSettings.gap || 10)
                onItemClicked: index => { page.selItem = index; page.tab = 1; }
            }

            Button {
                anchors.left: (page.stageSettings.position || "right") === "right" ? parent.left : undefined
                anchors.right: (page.stageSettings.position || "right") === "right" ? undefined : parent.right
                anchors.top: parent.top
                anchors.margins: 8
                text: page.panelPeek ? "\u{f0141}  Hide the agents panel" : "\u{f0142}  Peek at the agents panel"
                flat: true
                Material.foreground: "#eeeeee"
                focusPolicy: Qt.NoFocus
                font.pixelSize: 11
                onClicked: page.panelPeek = !page.panelPeek
            }
        }

        TabBar {
            visible: dock.available
            Layout.fillWidth: true
            currentIndex: page.tab
            onCurrentIndexChanged: page.tab = currentIndex
            background: null
            Repeater {
                model: ["Looks", "Items", "Agents", "Placement"]
                TabButton {
                    required property string modelData
                    text: modelData
                    focusPolicy: Qt.NoFocus
                    width: implicitWidth + 24
                }
            }
        }

        StackLayout {
            visible: dock.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: page.tab

            // ================= Looks =================
            ColumnLayout {
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Segmented {
                        model: [{ id: "presets", name: "Looks" }, { id: "shapes", name: "Shapes" }, { id: "colours", name: "Colours & magnify" }]
                        current: page.lookView
                        onPicked: id => page.lookView = id
                    }
                    Label {
                        Layout.leftMargin: 8
                        Layout.fillWidth: true
                        text: page.lookView === "presets" ? "Shape, tiles, colours and magnify together. Hover to try one on the stage."
                            : page.lookView === "shapes" ? "Each choice drawn as it would look."
                            : "The dock's colour, its accent, and the swell under the pointer."
                        color: theme.textDim
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                // --- whole looks ---
                GridView {
                    id: lookGrid
                    visible: page.lookView === "presets"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int columns: Math.max(2, Math.floor(width / 200))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 196
                    model: page.looks
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Item {
                        id: lookCell
                        required property var modelData
                        readonly property var merged: Object.assign({}, page.s, modelData.set, { position: "right" })
                        width: lookGrid.cellWidth
                        height: lookGrid.cellHeight
                        Tile {
                            id: lookTile
                            anchors.fill: parent
                            anchors.margins: 5
                            title: lookCell.modelData.name
                            subtitle: lookCell.modelData.desc
                            chosen: page.isLook(lookCell.modelData)
                            onPreviewWanted: on => on ? page.preview(lookCell.modelData.name, lookCell.modelData.set) : page.endPreview(lookCell.modelData.name)
                            onPicked: page.applyLook(lookCell.modelData)
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.darker(bar.themeColors.background || "#1a1b26", 1.2) }
                                    GradientStop { position: 1; color: Qt.tint(bar.themeColors.background || "#1a1b26", Qt.rgba(0.5, 0.4, 0.9, 0.18)) }
                                }
                            }
                            DockPreview {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                s: lookCell.merged
                                items: dock.dock.slice(0, 5)
                                agents: dock.agents
                                interactive: lookTile.hovered
                                fitHeight: parent.height - 12
                            }
                        }
                    }
                }

                // --- one choice at a time, each drawn ---
                ScrollView {
                    id: shapeScroll
                    visible: page.lookView === "shapes"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true
                    ColumnLayout {
                        width: shapeScroll.availableWidth
                        spacing: 12
                        Repeater {
                            model: [
                                { key: "dockShape", label: "Dock", fallback: "rounded",
                                  options: [["rounded", "Rounded"], ["pill", "Pill"], ["soft", "Soft"], ["square", "Square"], ["edge", "Attached to edge"]] },
                                { key: "iconShape", label: "Icon tiles", fallback: "rounded",
                                  options: [["rounded", "Rounded"], ["circle", "Circle"], ["squircle", "Squircle"], ["square", "Square"], ["diamond", "Diamond"]] },
                                { key: "iconPlate", label: "Show tiles", fallback: "hover",
                                  options: [["hover", "On hover"], ["always", "Always"], ["outline", "As outlines"]] },
                                { key: "dockBorder", label: "Border", fallback: "subtle",
                                  options: [["subtle", "Subtle"], ["accent", "Accent"], ["none", "None"]] }
                            ]
                            delegate: Card {
                                id: shapeCard
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: shapeCol.implicitHeight + 28
                                ColumnLayout {
                                    id: shapeCol
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8
                                    SectionLabel { text: shapeCard.modelData.label }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: shapeCard.modelData.options
                                            Tile {
                                                id: optionTile
                                                required property var modelData
                                                readonly property var change: ({ [shapeCard.modelData.key]: modelData[0] })
                                                width: 132
                                                height: 168
                                                title: modelData[1]
                                                chosen: (page.s[shapeCard.modelData.key] || shapeCard.modelData.fallback) === modelData[0]
                                                onPreviewWanted: on => on ? page.preview(modelData[1], change) : page.endPreview(modelData[1])
                                                onPicked: { page.endPreview(modelData[1]); dock.set(shapeCard.modelData.key, modelData[0]); }
                                                DockPreview {
                                                    anchors.centerIn: parent
                                                    s: Object.assign({}, page.s, optionTile.change, { position: "right", magnify: false, iconPlate: shapeCard.modelData.key === "iconPlate" ? optionTile.modelData[0] : (shapeCard.modelData.key === "iconShape" ? "always" : (page.s.iconPlate || "hover")) })
                                                    items: dock.dock.slice(0, 3)
                                                    interactive: optionTile.hovered
                                                    fitHeight: parent.height - 12
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Item { implicitHeight: 4 }
                    }
                }

                // --- colours and magnify ---
                ScrollView {
                    id: colourScroll
                    visible: page.lookView === "colours"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true
                    ColumnLayout {
                        width: colourScroll.availableWidth
                        spacing: 12
                        Repeater {
                            model: [
                                { key: "dockColor", label: "Dock colour", colors: page.dockColors, hint: "Light ones (Frost, Paper) switch the dock's text and icons to dark." },
                                { key: "accentColor", label: "Accent", colors: page.accentColors, hint: "The open agent tab, accent borders and highlights." }
                            ]
                            delegate: Card {
                                id: colourCard
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: colourCol.implicitHeight + 28
                                ColumnLayout {
                                    id: colourCol
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8
                                    RowLayout {
                                        SectionLabel { text: colourCard.modelData.label }
                                        Label { text: colourCard.modelData.hint; color: theme.textDim; font.pixelSize: 11; Layout.leftMargin: 8 }
                                    }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: ["theme"].concat(Object.keys(colourCard.modelData.colors))
                                            delegate: Rectangle {
                                                id: swatch
                                                required property string modelData
                                                readonly property bool chosen: (page.s[colourCard.modelData.key] || "theme") === modelData
                                                readonly property color shown: modelData === "theme"
                                                    ? (colourCard.modelData.key === "dockColor" ? (bar.themeColors.background || "#1a1b26") : theme.accent)
                                                    : colourCard.modelData.colors[modelData]
                                                readonly property string name: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                                width: 92
                                                height: 76
                                                radius: 10
                                                color: swatchHover.hovered ? theme.hover : theme.inset
                                                border.color: chosen ? theme.accent : theme.border
                                                border.width: chosen ? 2 : 1
                                                Rectangle {
                                                    x: 8; y: 8
                                                    width: parent.width - 16
                                                    height: 38
                                                    radius: 7
                                                    color: swatch.shown
                                                    border.color: theme.borderStrong
                                                }
                                                Label { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: swatch.name; color: swatch.chosen ? theme.accent : theme.textSoft; font.pixelSize: 11 }
                                                HoverHandler {
                                                    id: swatchHover
                                                    cursorShape: Qt.PointingHandCursor
                                                    onHoveredChanged: hovered ? page.preview(swatch.name, { [colourCard.modelData.key]: swatch.modelData }) : page.endPreview(swatch.name)
                                                }
                                                TapHandler { onTapped: { page.endPreview(swatch.name); dock.set(colourCard.modelData.key, swatch.modelData); } }
                                            }
                                        }
                                        // Any colour, as a #rrggbb.
                                        Rectangle {
                                            readonly property string value: page.s[colourCard.modelData.key] || ""
                                            readonly property bool chosen: value.startsWith("#")
                                            width: 92
                                            height: 76
                                            radius: 10
                                            color: theme.inset
                                            border.color: chosen ? theme.accent : theme.border
                                            border.width: chosen ? 2 : 1
                                            ColorButton {
                                                x: 8; y: 8
                                                width: parent.width - 16
                                                height: 38
                                                value: parent.value
                                                fallback: theme.accent
                                                title: colourCard.modelData.label
                                                onPicked: hex => dock.set(colourCard.modelData.key, hex)
                                            }
                                            Label { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; text: parent.chosen ? parent.value : "Any colour"; color: parent.chosen ? theme.accent : theme.textSoft; font.pixelSize: 11 }
                                        }
                                    }
                                }
                            }
                        }
                        Card {
                            Layout.fillWidth: true
                            implicitHeight: magCol.implicitHeight + 28
                            ColumnLayout {
                                id: magCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10
                                SectionLabel { text: "Magnify" }
                                SwitchRow {
                                    label: "Enlarge icons under the pointer"
                                    hint: "Like the macOS dock: the icon you point at grows and its neighbours a little less. Try it on the stage."
                                    checked: page.s.magnify === true
                                    onToggled: on => dock.set("magnify", on)
                                }
                                SliderRow {
                                    enabled: page.s.magnify === true
                                    label: "Largest size"
                                    from: 1.1; to: 2.4; stepSize: 0.05; suffix: "×"
                                    value: page.s.magnifyScale || 1.7
                                    onMoved: v => dock.set("magnifyScale", Math.round(v * 100) / 100)
                                }
                                SliderRow {
                                    enabled: page.s.magnify === true
                                    label: "Reach"
                                    from: 1; to: 4; stepSize: 1; decimals: 0; suffix: " icons"
                                    value: page.s.magnifyRange || 2
                                    onMoved: v => dock.set("magnifyRange", Math.round(v))
                                }
                                SliderRow {
                                    label: "Opacity"
                                    from: 0.3; to: 1; stepSize: 0.01
                                    value: page.s.opacity || 0.94
                                    onMoved: v => dock.set("opacity", Math.round(v * 100) / 100)
                                }
                            }
                        }
                        Item { implicitHeight: 4 }
                    }
                }
            }

            // ================= Items =================
            RowLayout {
                spacing: 12
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            SectionLabel { text: "On the dock, top to bottom · " + dock.dock.length }
                            Item { Layout.fillWidth: true }
                            Button { text: "+ Spacer"; flat: true; focusPolicy: Qt.NoFocus; onClicked: dock.addSpacer() }
                            Button { text: "+ Divider"; flat: true; focusPolicy: Qt.NoFocus; onClicked: dock.addDivider() }
                        }
                        Label { text: "Drag to reorder; click one for its details."; color: theme.textDim; font.pixelSize: 11 }
                        ListView {
                            id: itemList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: dragFrom < 0
                            model: dock.dock
                            ScrollBar.vertical: ScrollBar {}
                            property int dragFrom: -1
                            property int dragTo: -1
                            delegate: Item {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property bool picked: page.selItem === index
                                width: itemList.width - 12
                                height: 46
                                Rectangle {
                                    visible: itemList.dragFrom >= 0 && itemList.dragTo === row.index && itemList.dragTo !== itemList.dragFrom
                                    width: parent.width; height: 2; y: itemList.dragTo > itemList.dragFrom ? parent.height + 1 : -3
                                    color: theme.accent
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    opacity: itemList.dragFrom === row.index ? 0.4 : 1
                                    readonly property color tone: Qt.color(theme.accent)
                                    color: row.picked ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : rowHover.hovered ? theme.hover : theme.inset
                                    border.color: row.picked ? theme.accent : theme.border
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 4
                                        spacing: 8
                                        Label { text: "\u{f01dd}"; color: theme.textFaint; font.pixelSize: 12 }
                                        Rectangle {
                                            width: 30; height: 30; radius: 7
                                            color: theme.sunken
                                            Image {
                                                anchors.centerIn: parent
                                                width: 22; height: 22
                                                visible: row.modelData.type === "app" && (row.modelData.icon || "") !== ""
                                                source: visible ? "image://icon/" + row.modelData.icon : ""
                                                sourceSize: Qt.size(44, 44)
                                            }
                                            Label {
                                                anchors.centerIn: parent
                                                visible: row.modelData.type !== "app"
                                                text: row.modelData.type === "cmd" ? (row.modelData.glyph || "›") : row.modelData.type === "divider" ? "—" : "␣"
                                                color: theme.accent
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 15
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Label {
                                                Layout.fillWidth: true
                                                text: row.modelData.label || ""
                                                color: row.modelData.type === "spacer" || row.modelData.type === "divider" ? theme.textMuted : theme.text
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                visible: text !== ""
                                                text: row.modelData.type === "cmd" ? row.modelData.command
                                                    : row.modelData.type === "app" ? row.modelData.id + (row.modelData.missing ? " · not installed" : "") : ""
                                                color: row.modelData.missing ? theme.danger : theme.textFaint
                                                font.pixelSize: 10
                                                font.family: "monospace"
                                                elide: Text.ElideMiddle
                                            }
                                        }
                                        ToolButton {
                                            opacity: rowHover.hovered || row.picked ? 1 : 0
                                            enabled: opacity > 0
                                            text: "\u{f0156}"
                                            implicitWidth: 28; implicitHeight: 28
                                            font.pixelSize: 13
                                            focusPolicy: Qt.NoFocus
                                            onClicked: { dock.removeItem(row.index); page.selItem = -1; }
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Take off the dock"
                                        }
                                    }
                                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: page.selItem = row.index }
                                    DragHandler {
                                        target: null
                                        dragThreshold: 6
                                        yAxis.enabled: true
                                        xAxis.enabled: false
                                        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                        onActiveChanged: {
                                            if (active) { itemList.dragFrom = row.index; itemList.dragTo = row.index; }
                                            else {
                                                // The move rebuilds the list, this row included, so
                                                // everything else happens first.
                                                const from = itemList.dragFrom, to = itemList.dragTo;
                                                itemList.dragFrom = -1;
                                                itemList.dragTo = -1;
                                                if (from >= 0 && to >= 0 && to !== from) {
                                                    page.selItem = to;
                                                    dock.moveItem(from, to);
                                                }
                                            }
                                        }
                                        onTranslationChanged: if (active) itemList.dragTo = Math.max(0, Math.min(dock.dock.length - 1, row.index + Math.round(translation.y / 50)))
                                    }
                                }
                            }
                        }
                    }
                }

                // --- right: the picked item, or what to add ---
                Card {
                    id: itemCard
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    readonly property var picked: page.selItem >= 0 ? dock.dock[page.selItem] : undefined
                    readonly property bool hasItem: picked !== undefined && picked !== null
                    readonly property var item: hasItem ? picked : ({})
                    ColumnLayout {
                        visible: itemCard.hasItem
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                width: 44; height: 44; radius: 10
                                color: theme.sunken
                                Image {
                                    anchors.centerIn: parent
                                    width: 32; height: 32
                                    visible: itemCard.item.type === "app" && (itemCard.item.icon || "") !== ""
                                    source: visible ? "image://icon/" + itemCard.item.icon : ""
                                    sourceSize: Qt.size(64, 64)
                                }
                                Label {
                                    anchors.centerIn: parent
                                    visible: itemCard.item.type !== "app"
                                    text: itemCard.item.type === "cmd" ? (itemCard.item.glyph || "›") : itemCard.item.type === "divider" ? "—" : "␣"
                                    color: theme.accent
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 20
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { Layout.fillWidth: true; text: itemCard.item.label || ""; color: theme.text; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Label { text: ({ app: "App", cmd: "Command", spacer: "Spacer", divider: "Divider" })[itemCard.item.type] || ""; color: theme.textFaint; font.pixelSize: 11 }
                            }
                            ToolButton { text: "\u{f0156}"; focusPolicy: Qt.NoFocus; onClicked: page.selItem = -1; ToolTip.visible: hovered; ToolTip.text: "Done (Esc)" }
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: itemCard.item.type === "cmd" ? "Runs: " + itemCard.item.command
                                : itemCard.item.type === "app" ? itemCard.item.id + ".desktop" + (itemCard.item.missing ? "\nThis app isn't installed any more." : "") : ""
                            color: itemCard.item.missing ? theme.danger : theme.textMuted
                            font.family: "monospace"
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: (page.selItem + 1) + " of " + dock.dock.length; color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                            ToolButton { text: "\u{f0143}"; enabled: page.selItem > 0; focusPolicy: Qt.NoFocus; onClicked: { dock.moveItem(page.selItem, page.selItem - 1); page.selItem--; } }
                            ToolButton { text: "\u{f0140}"; enabled: page.selItem < dock.dock.length - 1; focusPolicy: Qt.NoFocus; onClicked: { dock.moveItem(page.selItem, page.selItem + 1); page.selItem++; } }
                        }
                        Button {
                            text: "Take off the dock"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            onClicked: { dock.removeItem(page.selItem); page.selItem = -1; }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    ColumnLayout {
                        visible: !itemCard.hasItem
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        SectionLabel { text: "Add an app" }
                        TextField { id: appSearch; Layout.fillWidth: true; placeholderText: "Search installed apps" }
                        ListView {
                            id: appList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: page.active && page.tab === 1 ? dock.apps(appSearch.text) : []
                            ScrollBar.vertical: ScrollBar {}
                            delegate: ItemDelegate {
                                required property var modelData
                                width: appList.width - 12
                                height: 38
                                focusPolicy: Qt.NoFocus
                                contentItem: RowLayout {
                                    spacing: 10
                                    Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: modelData.icon ? "image://icon/" + modelData.icon : ""; sourceSize: Qt.size(44, 44) }
                                    Label { Layout.fillWidth: true; text: modelData.name; color: theme.text; elide: Text.ElideRight }
                                    Label { text: "Add"; color: theme.accent; font.pixelSize: 12 }
                                }
                                onClicked: dock.addApp(modelData.id)
                            }
                        }
                        SectionLabel { text: "Add a command"; Layout.topMargin: 6 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            TextField { id: cmdName; Layout.fillWidth: true; placeholderText: "Name" }
                            TextField { id: cmdGlyph; Layout.preferredWidth: 64; placeholderText: "Glyph"; font.family: "JetBrainsMono Nerd Font" }
                        }
                        TextField { id: cmdLine; Layout.fillWidth: true; placeholderText: "Command, e.g. omarchy-launch-browser"; font.family: "monospace" }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: "Add command"
                            focusPolicy: Qt.NoFocus
                            enabled: cmdName.text.trim() !== "" && cmdLine.text.trim() !== ""
                            onClicked: { dock.addCommand(cmdName.text, cmdGlyph.text, cmdLine.text); cmdName.text = ""; cmdGlyph.text = ""; cmdLine.text = ""; }
                        }
                    }
                }
            }

            // ================= Agents =================
            RowLayout {
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: dock.customAgents ? "Agents come from " + page.home(dock.configPath) + ", which the dock reloads on save."
                                                    : "The dock's built-in agents. Changing them writes " + page.home(dock.configPath) + "."
                            color: theme.textDim
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Button { text: "+ Agent"; flat: true; focusPolicy: Qt.NoFocus; onClicked: page.editing = -1 }
                        Button { text: "Reset to built-in"; flat: true; focusPolicy: Qt.NoFocus; visible: dock.customAgents; onClicked: { page.editing = -2; dock.resetAgents(); } }
                    }
                    GridView {
                        id: agentGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        readonly property int columns: Math.max(1, Math.floor(width / 260))
                        cellWidth: Math.floor(width / columns)
                        cellHeight: 128
                        model: dock.agents
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Item {
                            id: agentCell
                            required property var modelData
                            required property int index
                            width: agentGrid.cellWidth
                            height: agentGrid.cellHeight
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                radius: 10
                                readonly property color tone: Qt.color(theme.accent)
                                readonly property bool picked: page.editing === agentCell.index
                                color: picked ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : agentHover.hovered ? theme.hover : theme.inset
                                border.color: picked ? theme.accent : theme.border
                                border.width: picked ? 2 : 1
                                opacity: agentCell.modelData.shown ? 1 : 0.6
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6
                                    RowLayout {
                                        spacing: 10
                                        Rectangle {
                                            width: 40; height: 40; radius: 10
                                            color: theme.sunken
                                            Image { anchors.centerIn: parent; width: 26; height: 26; source: agentCell.modelData.iconUrl || ""; sourceSize: Qt.size(52, 52) }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Label { Layout.fillWidth: true; text: agentCell.modelData.name; color: theme.text; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                            StatePill { text: agentCell.modelData.installed ? "installed" : "not installed"; on: agentCell.modelData.installed }
                                        }
                                        Switch {
                                            checked: agentCell.modelData.shown
                                            focusPolicy: Qt.NoFocus
                                            onToggled: dock.setAgentShown(agentCell.modelData.id, checked)
                                            ToolTip.visible: hovered
                                            ToolTip.text: checked ? "Its tab shows in the panel" : "Hidden from the panel"
                                        }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: agentCell.modelData.command + (agentCell.modelData.cwd ? "  in " + agentCell.modelData.cwd : "")
                                        color: theme.textDim
                                        font.family: "monospace"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        visible: !agentCell.modelData.installed && (agentCell.modelData.install || "") !== ""
                                        text: "installs with: " + agentCell.modelData.install
                                        color: theme.textFaint
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                                HoverHandler { id: agentHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: page.editing = agentCell.index }
                            }
                        }
                    }
                }

                // --- the picked agent, edited ---
                Card {
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    readonly property var agent: page.editing >= 0 ? (dock.agents[page.editing] || {}) : ({})
                    onAgentChanged: {
                        agentId.text = agent.id || ""; agentName.text = agent.name || "";
                        agentCommand.text = agent.command || ""; agentIcon.text = agent.icon || "";
                        agentInstall.text = agent.install || ""; agentCwd.text = agent.cwd || "";
                    }
                    Label {
                        visible: page.editing === -2
                        anchors.centerIn: parent
                        width: parent.width - 40
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Click an agent to edit it, or add one. Each gets a terminal tab in the dock's panel."
                        color: theme.textDim
                    }
                    ScrollView {
                        id: agentScroll
                        visible: page.editing !== -2
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: availableWidth
                        clip: true
                        ColumnLayout {
                            width: agentScroll.availableWidth - 2
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                SectionLabel { text: page.editing === -1 ? "New agent" : "Edit agent"; Layout.fillWidth: true }
                                ToolButton { text: "\u{f0156}"; focusPolicy: Qt.NoFocus; onClicked: page.editing = -2 }
                            }
                            Label { text: "Id"; color: theme.textSoft; font.pixelSize: 12 }
                            TextField { id: agentId; Layout.fillWidth: true; placeholderText: "codex"; font.family: "monospace" }
                            Label { text: "Name"; color: theme.textSoft; font.pixelSize: 12 }
                            TextField { id: agentName; Layout.fillWidth: true; placeholderText: "Codex" }
                            Label { text: "Command"; color: theme.textSoft; font.pixelSize: 12 }
                            TextField { id: agentCommand; Layout.fillWidth: true; placeholderText: "codex"; font.family: "monospace" }
                            Label { text: "Icon"; color: theme.textSoft; font.pixelSize: 12 }
                            TextField { id: agentIcon; Layout.fillWidth: true; placeholderText: "/path/to/icon.svg, or icons/x.svg"; font.family: "monospace" }
                            Label { text: "Install with"; color: theme.textSoft; font.pixelSize: 12 }
                            TextField { id: agentInstall; Layout.fillWidth: true; placeholderText: "omarchy pkg add codex"; font.family: "monospace" }
                            Label { text: "Folder"; color: theme.textSoft; font.pixelSize: 12 }
                            TextField { id: agentCwd; Layout.fillWidth: true; placeholderText: "~/Work (the start folder when empty)"; font.family: "monospace" }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                Button {
                                    text: "Remove"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    visible: page.editing >= 0
                                    enabled: dock.agents.length > 1
                                    onClicked: { dock.removeAgent(page.editing); page.editing = -2; }
                                }
                                Item { Layout.fillWidth: true }
                                AccentButton {
                                    text: "Save agent"
                                    enabled: agentId.text.trim() !== "" && agentCommand.text.trim() !== ""
                                    onClicked: {
                                        dock.saveAgent(page.editing, { id: agentId.text, name: agentName.text, command: agentCommand.text,
                                                                       icon: agentIcon.text, install: agentInstall.text, cwd: agentCwd.text });
                                        page.editing = -2;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================= Placement =================
            ScrollView {
                id: placeScroll
                contentWidth: availableWidth
                clip: true
                GridLayout {
                    width: placeScroll.availableWidth
                    columns: width > 900 ? 2 : 1
                    columnSpacing: 14
                    rowSpacing: 14
                    Card {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: whereCol.implicitHeight + 28
                        ColumnLayout {
                            id: whereCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            SectionLabel { text: "Where" }
                            RowLayout {
                                spacing: 18
                                EdgePicker {
                                    edges: ["left", "right"]
                                    current: page.s.position || "right"
                                    onPicked: edge => dock.set("position", edge)
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Label { text: "Monitor"; color: theme.textSoft }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Chip { text: "Focused"; chosen: dock.monitor === ""; onClicked: dock.setMonitor("") }
                                        Repeater {
                                            model: dock.monitors
                                            Chip { required property string modelData; text: modelData; chosen: dock.monitor === modelData; onClicked: dock.setMonitor(modelData) }
                                        }
                                    }
                                }
                            }
                            SliderRow { label: "Floating gap"; from: 0; to: 48; stepSize: 1; decimals: 0; suffix: " px"; value: page.s.gap || 0; onMoved: v => dock.set("gap", Math.round(v)) }
                            SliderRow { label: "Icon size"; from: 18; to: 56; stepSize: 1; decimals: 0; suffix: " px"; value: page.s.iconSize || 28; onMoved: v => dock.set("iconSize", Math.round(v)) }
                            SliderRow { label: "Opacity"; from: 0.3; to: 1; stepSize: 0.01; value: page.s.opacity || 0.94; onMoved: v => dock.set("opacity", Math.round(v * 100) / 100) }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: panelCol.implicitHeight + 28
                        ColumnLayout {
                            id: panelCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            SectionLabel { text: "The agents panel" }
                            SliderRow { label: "Panel width"; from: 320; to: 1600; stepSize: 10; decimals: 0; suffix: " px"; value: page.s.width || 520; onMoved: v => dock.set("width", Math.round(v)) }
                            SwitchRow {
                                label: "Reserve space while collapsed"
                                hint: "Windows tile beside the dock instead of under it."
                                checked: page.s.reserveCollapsed === true
                                onToggled: on => dock.set("reserveCollapsed", on)
                            }
                            SwitchRow {
                                label: "Reserve space while expanded"
                                hint: "Windows make room for the agent panel when it opens."
                                checked: page.s.reserveExpanded === true
                                onToggled: on => dock.set("reserveExpanded", on)
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Label { Layout.preferredWidth: 120; text: "Start folder"; color: theme.textSoft }
                                TextField {
                                    Layout.fillWidth: true
                                    text: page.s.cwd || ""
                                    placeholderText: "~ (home)"
                                    font.family: "monospace"
                                    onEditingFinished: if (text !== (page.s.cwd || "")) dock.set("cwd", text.trim())
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "New agent sessions start here, unless the agent has its own folder."
                                color: theme.textDim
                                font.pixelSize: 11
                            }
                        }
                    }
                    Item { implicitHeight: 4 }
                }
            }
        }
    }
}

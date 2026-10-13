import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// omabar16: themes, layouts, which widgets go where, and the style keys.
// Every change goes to the live bar at once, through omabar16 itself.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    property int tab: 0
    property string group: "All"
    readonly property var st: bar.style
    readonly property bool ready: bar.available && bar.inUse
    readonly property var lanes: [{ id: "left", name: "Left" }, { id: "center", name: "Centre" }, { id: "right", name: "Right" }]
    readonly property var shortcuts: [
        { keys: "T / L / M / S", action: "Themes, Layout, Modules, Style" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo), through omabar16" },
        { keys: "O", action: "Open omabar16's own customizer" }
    ]

    function handleEscape() {
        if (bar.error !== "" || bar.notice !== "") {
            bar.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}

    // Looked up here rather than through page.widgetName(), so names fill in
    // when the widget list arrives.
    function widgetName(id) {
        const widget = bar.widgets.find(w => w.id === id);
        return widget ? widget.name : id.split(".").pop();
    }

    // A palette entry is a hex colour or an Omarchy theme colour's name.
    function swatch(value, fallback) {
        return String(value || "").startsWith("#") ? value : fallback;
    }
    function moduleColor(id, lane, index) {
        const modules = st.modules || {};
        if (modules[id]) return modules[id];
        const regions = st.regions || {};
        if (regions[lane]) return regions[lane];
        const palette = st.palette || [];
        if (st.colors === "mono" || palette.length === 0) return swatch(st.accent, theme.accent);
        return swatch(palette[index % palette.length], theme.accent);
    }

    onActiveChanged: if (active) { bar.reload(); bar.refreshWidgets(); }

    readonly property bool keys: active && keysFree && bar.available
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 0 }
    Shortcut { sequence: "L"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 1 }
    Shortcut { sequence: "M"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 2 }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 3 }
    Shortcut { sequence: "O"; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: bar.openCustomizer("") }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: bar.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: bar.redo() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Bar"
            subtitle: "omabar16: themes, layouts, widgets and style, applied to the live bar"
            glyph: "\u{f0570}"
            Button { text: "Undo"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.ready; onClicked: bar.undo() }
            Button { text: "Redo"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.ready; onClicked: bar.redo() }
            Button { text: "Revert"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.ready; onClicked: bar.revert() }
            Button { text: "Full customizer"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.ready; onClicked: bar.openCustomizer("") }
        }

        NotInstalled {
            visible: !bar.available
            pluginId: "omabar16"
            what: "The bar, its themes and its customizer are the omabar16 plugin."
        }

        MessageBar {
            error: bar.error
            notice: bar.notice
            onDismissed: bar.dismissMessages()
        }

        // Installed but another bar is showing.
        Rectangle {
            visible: bar.available && !bar.inUse
            Layout.fillWidth: true
            implicitHeight: useRow.implicitHeight + 20
            radius: 8
            color: "#1c1a12"
            border.color: "#5a4f26"
            RowLayout {
                id: useRow
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 14
                Label {
                    Layout.fillWidth: true
                    text: "Your bar is " + bar.barId + ", not omabar16, so changes here wouldn't show. Use omabar16 to edit it."
                    color: "#e6d9a6"
                    wrapMode: Text.WordWrap
                }
                AccentButton {
                    text: "Use omabar16"
                    onClicked: bar.useAsBar()
                }
            }
        }

        // A sketch of the bar as it is: each widget as a segment.
        Rectangle {
            visible: bar.available
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Math.min(10, (page.st.radius || 0) + 4)
            color: page.swatch(page.st.bg, "#121416")
            border.color: "#26262b"
            opacity: page.ready ? 1 : 0.5
            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 0
                Repeater {
                    model: page.lanes
                    delegate: RowLayout {
                        id: laneSketch
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: Math.max(2, page.st.gap || 2)
                        Item { visible: laneSketch.index > 0; Layout.fillWidth: true }
                        Repeater {
                            model: (bar.layout[laneSketch.modelData.id] || [])
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                implicitWidth: glyph.implicitWidth + 18
                                implicitHeight: 26
                                radius: page.st.shape === "round" ? 13 : page.st.shape === "block" ? (page.st.radius || 3) : 3
                                readonly property color fill: Qt.color(page.moduleColor(modelData.id, laneSketch.modelData.id, index))
                                color: page.st.solid ? fill : Qt.rgba(fill.r, fill.g, fill.b, Math.max(0.2, page.st.tint || 0.3))
                                Label {
                                    id: glyph
                                    anchors.centerIn: parent
                                    text: modelData.icon || bar.glyphFor(modelData.id)
                                    color: page.st.solid ? page.swatch(page.st.fg, "#111") : "white"
                                    font.family: modelData.iconFont || "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                ToolTip.visible: segHover.hovered
                                ToolTip.text: page.widgetName(modelData.id)
                                HoverHandler { id: segHover }
                            }
                        }
                        Item { visible: laneSketch.index < 2; Layout.fillWidth: true }
                    }
                }
            }
        }

        TabBar {
            visible: bar.available
            Layout.fillWidth: true
            currentIndex: page.tab
            onCurrentIndexChanged: page.tab = currentIndex
            background: null
            Repeater {
                model: ["Themes", "Layout", "Modules", "Style"]
                TabButton {
                    required property string modelData
                    text: modelData
                    focusPolicy: Qt.NoFocus
                    width: implicitWidth + 24
                }
            }
        }

        StackLayout {
            visible: bar.available
            enabled: page.ready
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: page.tab

            // --- Themes ---
            ColumnLayout {
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: ["All", "Looks", "JaKooLit", "base16", "Yours"]
                        Chip {
                            required property string modelData
                            text: modelData
                            chosen: page.group === modelData
                            onClicked: page.group = modelData
                        }
                    }
                    Item { Layout.fillWidth: true }
                    TextField { id: themeSearch; Layout.preferredWidth: 220; placeholderText: "Search themes" }
                }
                ScrollView {
                    id: themeScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true
                    GridLayout {
                        width: themeScroll.availableWidth
                        columns: Math.max(2, Math.floor(width / 230))
                        rowSpacing: 10
                        columnSpacing: 10
                        Repeater {
                            model: bar.themes.filter(t => (page.group === "All" || t.group === page.group)
                                                     && (themeSearch.text === "" || (t.label + " " + (t.desc || "")).toLowerCase().indexOf(themeSearch.text.toLowerCase()) >= 0))
                            delegate: Rectangle {
                                id: themeTile
                                required property var modelData
                                readonly property bool current: bar.currentTheme === modelData.id
                                readonly property color tone: Qt.color(theme.accent)
                                Layout.fillWidth: true
                                implicitHeight: 82
                                radius: 9
                                color: current ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : tileHover.hovered ? "#1b1b1f" : "#111113"
                                border.color: current ? theme.accent : "#26262b"
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 5
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label { text: themeTile.modelData.label; color: themeTile.current ? theme.accent : "white"; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Label { text: themeTile.modelData.group; color: "#5f5f68"; font.pixelSize: 10 }
                                    }
                                    Row {
                                        spacing: 3
                                        Repeater {
                                            model: themeTile.modelData.swatches
                                            Rectangle { required property string modelData; width: 22; height: 10; radius: 2; color: modelData }
                                        }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: themeTile.modelData.desc || ""
                                        color: "#8a8a93"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: bar.applyTheme(themeTile.modelData.id) }
                            }
                        }
                    }
                }
            }

            // --- Layout ---
            ScrollView {
                id: layoutScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: layoutScroll.availableWidth
                    spacing: 14
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: placeColumn.implicitHeight + 32
                        ColumnLayout {
                            id: placeColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            RowLayout {
                                spacing: 8
                                Label { Layout.preferredWidth: 120; text: "Screen edge"; color: "#d6d6da" }
                                Repeater {
                                    model: ["top", "bottom", "left", "right"]
                                    Chip {
                                        required property string modelData
                                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                        chosen: bar.position === modelData
                                        onClicked: bar.setPosition(modelData)
                                    }
                                }
                            }
                            SwitchRow {
                                label: "Transparent"
                                hint: "The bar's background shows the wallpaper; segments keep their colours."
                                checked: bar.transparent
                                onToggled: on => bar.setTransparent(on)
                            }
                        }
                    }
                    SectionLabel { text: "Preset layouts · widgets move, their settings stay" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.floor(width / 300))
                        rowSpacing: 8
                        columnSpacing: 8
                        Repeater {
                            model: bar.layouts
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 62
                                radius: 9
                                color: layoutHover.hovered ? "#1b1b1f" : "#111113"
                                border.color: "#26262b"
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label { text: modelData.label; color: "white"; font.weight: Font.DemiBold }
                                        Item { Layout.fillWidth: true }
                                        Label { text: modelData.counts; color: "#5f5f68"; font.pixelSize: 10; font.family: "monospace" }
                                    }
                                    Label { Layout.fillWidth: true; text: modelData.desc || ""; color: "#8a8a93"; font.pixelSize: 11; elide: Text.ElideRight }
                                }
                                HoverHandler { id: layoutHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: bar.applyLayout(modelData.id) }
                            }
                        }
                    }
                }
            }

            // --- Modules ---
            ColumnLayout {
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label { text: "Add"; color: "#d6d6da" }
                    ComboBox {
                        id: widgetChoice
                        Layout.preferredWidth: 260
                        model: bar.widgets
                        textRole: "name"
                        valueRole: "id"
                        focusPolicy: Qt.NoFocus
                    }
                    Label { text: "to the"; color: "#d6d6da" }
                    Repeater {
                        model: page.lanes
                        Chip {
                            required property var modelData
                            text: modelData.name
                            onClicked: if (widgetChoice.currentValue) bar.addWidget(widgetChoice.currentValue, modelData.id)
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    Repeater {
                        model: page.lanes
                        delegate: Card {
                            id: laneCard
                            required property var modelData
                            required property int index
                            readonly property var entries: bar.layout[modelData.id] || []
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6
                                SectionLabel { text: laneCard.modelData.name + " · " + laneCard.entries.length }
                                ListView {
                                    id: laneList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 4
                                    model: laneCard.entries
                                    delegate: Rectangle {
                                        id: entry
                                        required property var modelData
                                        required property int index
                                        width: laneList.width
                                        height: 38
                                        radius: 7
                                        color: "#111113"
                                        border.color: "#26262b"
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            spacing: 2
                                            Label {
                                                text: entry.modelData.icon || bar.glyphFor(entry.modelData.id)
                                                color: theme.accent
                                                font.family: entry.modelData.iconFont || "JetBrainsMono Nerd Font"
                                                Layout.preferredWidth: 20
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                text: page.widgetName(entry.modelData.id)
                                                color: "white"
                                                elide: Text.ElideRight
                                                font.pixelSize: 12
                                            }
                                            ToolButton {
                                                text: "←"; focusPolicy: Qt.NoFocus; visible: laneCard.index > 0
                                                onClicked: bar.moveWidget(laneCard.modelData.id, entry.index, page.lanes[laneCard.index - 1].id, 9999)
                                            }
                                            ToolButton { text: "↑"; focusPolicy: Qt.NoFocus; enabled: entry.index > 0; onClicked: bar.moveWidget(laneCard.modelData.id, entry.index, laneCard.modelData.id, entry.index - 1) }
                                            ToolButton { text: "↓"; focusPolicy: Qt.NoFocus; enabled: entry.index < laneCard.entries.length - 1; onClicked: bar.moveWidget(laneCard.modelData.id, entry.index, laneCard.modelData.id, entry.index + 1) }
                                            ToolButton {
                                                text: "→"; focusPolicy: Qt.NoFocus; visible: laneCard.index < 2
                                                onClicked: bar.moveWidget(laneCard.modelData.id, entry.index, page.lanes[laneCard.index + 1].id, 9999)
                                            }
                                            ToolButton { text: "✕"; focusPolicy: Qt.NoFocus; onClicked: bar.removeWidget(laneCard.modelData.id, entry.index) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- Style ---
            ScrollView {
                id: styleScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: styleScroll.availableWidth
                    spacing: 14
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: shapeColumn.implicitHeight + 32
                        ColumnLayout {
                            id: shapeColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            SectionLabel { text: "Segments" }
                            RowLayout {
                                spacing: 6
                                Label { Layout.preferredWidth: 120; text: "Shape"; color: "#d6d6da" }
                                Repeater {
                                    model: [{ id: "arrow", name: "Chevron" }, { id: "slant", name: "Slant" }, { id: "round", name: "Pill" },
                                            { id: "block", name: "Block" }, { id: "none", name: "None" }]
                                    Chip {
                                        required property var modelData
                                        text: modelData.name
                                        chosen: (page.st.shape || "none") === modelData.id
                                        onClicked: bar.setStyle("shape", modelData.id)
                                    }
                                }
                            }
                            RowLayout {
                                spacing: 6
                                Label { Layout.preferredWidth: 120; text: "Colours"; color: "#d6d6da" }
                                Chip { text: "Cycle the palette"; chosen: page.st.colors !== "mono"; onClicked: bar.setStyle("colors", "cycle") }
                                Chip { text: "One colour"; chosen: page.st.colors === "mono"; onClicked: bar.setStyle("colors", "mono") }
                            }
                            SwitchRow {
                                label: "Solid fill"
                                hint: "Off washes each segment into the bar background by the tint below."
                                checked: page.st.solid === true
                                onToggled: on => bar.setStyle("solid", on)
                            }
                            SwitchRow {
                                label: "Flat ends"
                                hint: "Square off the outer ends of chevron and slant runs."
                                checked: page.st.flatEnds === true
                                onToggled: on => bar.setStyle("flatEnds", on)
                            }
                            SliderRow { label: "Tint"; from: 0; to: 1; value: page.st.tint !== undefined ? page.st.tint : 0.3; onMoved: v => bar.setStyle("tint", v.toFixed(2)) }
                            SliderRow { label: "Depth"; from: 0; to: 1; value: page.st.depth !== undefined ? page.st.depth : 0.42; onMoved: v => bar.setStyle("depth", v.toFixed(2)) }
                            SliderRow { label: "Gap"; from: 0; to: 16; stepSize: 1; decimals: 0; value: page.st.gap || 0; onMoved: v => bar.setStyle("gap", Math.round(v)) }
                            SliderRow { label: "Inset"; from: 0; to: 12; stepSize: 1; decimals: 0; value: page.st.inset || 0; onMoved: v => bar.setStyle("inset", Math.round(v)) }
                            SliderRow { label: "Segment opacity"; from: 0.1; to: 1; value: page.st.segmentOpacity !== undefined ? page.st.segmentOpacity : 1; onMoved: v => bar.setStyle("segmentOpacity", v.toFixed(2)) }
                            SliderRow { label: "Hover opacity"; from: 0; to: 1; value: page.st.hoverOpacity !== undefined ? page.st.hoverOpacity : 0.2; onMoved: v => bar.setStyle("hoverOpacity", v.toFixed(2)) }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: frameColumn.implicitHeight + 32
                        ColumnLayout {
                            id: frameColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            SectionLabel { text: "The bar" }
                            SliderRow { label: "Thickness"; from: 16; to: 56; stepSize: 1; decimals: 0; suffix: " px"; value: page.st.size || 26; onMoved: v => bar.setStyle("size", Math.round(v)) }
                            SliderRow { label: "Corner radius"; from: 0; to: 24; stepSize: 1; decimals: 0; suffix: " px"; value: page.st.radius || 0; onMoved: v => bar.setStyle("radius", Math.round(v)) }
                            SliderRow { label: "Padding"; from: 0; to: 24; stepSize: 1; decimals: 0; suffix: " px"; value: page.st.pad || 0; onMoved: v => bar.setStyle("pad", Math.round(v)) }
                            SliderRow { label: "Edge padding"; from: 0; to: 32; stepSize: 1; decimals: 0; suffix: " px"; value: page.st.edge || 0; onMoved: v => bar.setStyle("edge", Math.round(v)) }
                            SliderRow { label: "Float"; from: 0; to: 24; stepSize: 1; decimals: 0; suffix: " px"; value: page.st.float || 0; onMoved: v => bar.setStyle("float", Math.round(v)) }
                            SliderRow { label: "Bar opacity"; from: 0; to: 1; value: page.st.barOpacity !== undefined ? page.st.barOpacity : 1; onMoved: v => bar.setStyle("barOpacity", v.toFixed(2)) }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Label { Layout.preferredWidth: 120; text: "Font"; color: "#d6d6da" }
                                TextField {
                                    Layout.fillWidth: true
                                    text: page.st.fontFamily || ""
                                    placeholderText: "The shell's font"
                                    onEditingFinished: if (text !== (page.st.fontFamily || "")) bar.setStyle("fontFamily", text.trim())
                                }
                            }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: colorColumn.implicitHeight + 32
                        ColumnLayout {
                            id: colorColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            SectionLabel { text: "Colours · #rrggbb, or empty to follow the Omarchy theme" }
                            Repeater {
                                model: [{ part: "bg", name: "Background", key: "bg" }, { part: "fg", name: "Text on segments", key: "fg" },
                                        { part: "accent", name: "Accent", key: "accent" }, { part: "region:left", name: "Left region", key: "" },
                                        { part: "region:center", name: "Centre region", key: "" }, { part: "region:right", name: "Right region", key: "" }]
                                delegate: RowLayout {
                                    id: colorRow
                                    required property var modelData
                                    readonly property string current: modelData.key !== "" ? (page.st[modelData.key] || "")
                                                                     : ((page.st.regions || {})[modelData.part.split(":")[1]] || "")
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Label { Layout.preferredWidth: 120; text: colorRow.modelData.name; color: "#d6d6da" }
                                    Rectangle {
                                        width: 26; height: 26; radius: 6
                                        color: /^#[0-9a-fA-F]{6}$/.test(hexField.text) ? hexField.text : "transparent"
                                        border.color: "#3a3a40"
                                    }
                                    TextField {
                                        id: hexField
                                        Layout.preferredWidth: 130
                                        text: colorRow.current
                                        placeholderText: "theme"
                                        font.family: "monospace"
                                        onEditingFinished: {
                                            const value = text.trim();
                                            if (value === colorRow.current) return;
                                            // Clearing bg, fg or accent removes the key, so the
                                            // bar follows the Omarchy theme again.
                                            if (value === "" && colorRow.modelData.key !== "") bar.setStyle(colorRow.modelData.key, "");
                                            else if (value === "" || /^#[0-9a-fA-F]{6}$/.test(value)) bar.setColor(colorRow.modelData.part, value);
                                            else text = colorRow.current;
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "Per-widget colours, icons and the hex picker are in the full customizer's Studio tab."
                                color: "#74747d"
                                font.pixelSize: 11
                            }
                            Button {
                                text: "Open Studio"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                onClicked: bar.openCustomizer("studio")
                            }
                        }
                    }
                    Item { implicitHeight: 4 }
                }
            }
        }
    }
}
